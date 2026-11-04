#!/bin/sh
# 把离线插件包里的插件装进便捷包当前的 Profile（不需要网络）。
#
# 用法：
#   ./install-plugins.sh                 # 安装 ./plugins-offline 里的全部插件
#   ./install-plugins.sh <插件包目录>     # 指定插件包目录
#   ./install-plugins.sh --list          # 只列出清单，不安装
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

LIST_ONLY=0
BUNDLE=""
for arg in "$@"; do
  case "$arg" in
    --list|-l) LIST_ONLY=1 ;;
    -*) echo "未知参数：$arg" >&2; exit 1 ;;
    *) BUNDLE="$arg" ;;
  esac
done
# 目标便捷包：安装脚本既可能被放在包的顶层，也可能独立分发。
PKG="${DSH_NEXT_PACKAGE:-$DIR}"
if [ ! -x "$PKG/dsh-desktop-next" ] && [ ! -f "$PKG/dsh-desktop-next.exe" ] && [ ! -x "$PKG/DSH NEXT.exe" ]; then
  PKG="$DIR"
fi

# 插件包来源优先级：显式参数 > 同目录 plugins-offline/ > 包内 registry/ > 脚本所在目录
if [ -z "$BUNDLE" ]; then
  if [ -d "$DIR/plugins-offline" ]; then BUNDLE="$DIR/plugins-offline"
  elif [ -d "$PKG/registry" ]; then BUNDLE="$PKG/registry"
  else BUNDLE="$DIR"; fi
fi

if [ ! -d "$BUNDLE" ]; then
  echo "找不到插件包目录：$BUNDLE" >&2
  exit 1
fi

# 清单优先读打包时写下的 plugins.json，缺失时退回 tgz 文件名。
list_plugins() {
  if [ -f "$BUNDLE/plugins.json" ]; then
    "$(command -v node || echo node)" -e '
      const doc = require(process.argv[1]);
      doc.plugins.forEach(p => console.log(`  ${p.name}@${p.version}`));
    ' "$BUNDLE/plugins.json" 2>/dev/null && return 0
  fi
  for tgz in "$BUNDLE"/*.tgz; do
    [ -e "$tgz" ] || continue
    echo "  $(basename "$tgz" .tgz)"
  done
}

if [ "$LIST_ONLY" -eq 1 ]; then
  echo "离线插件包：$BUNDLE"
  list_plugins
  if [ -d "$BUNDLE/store" ]; then
    echo "store：$(du -sh "$BUNDLE/store" 2>/dev/null | cut -f1)"
  fi
  exit 0
fi

export DSH_DESKTOP_NEXT_HOME="${DSH_DESKTOP_NEXT_HOME:-$PKG/home/data}"
PROFILE_DIR="$DSH_DESKTOP_NEXT_HOME/profiles/desktop"
if [ ! -d "$PROFILE_DIR" ]; then
  echo "Profile 尚未创建：请先启动一次便捷包，再运行本脚本" >&2
  exit 1
fi
# 不导出 NPM_CONFIG_CACHE/_STORE_DIR：大写变量会让 pnpm 的 cacheDir 解析成空值，
# 路径统一用命令行标志传入（camelCase，等号形式）。
unset NPM_CONFIG_CACHE NPM_CONFIG_STORE_DIR 2>/dev/null || true
export NPM_CONFIG_USERCONFIG="$PKG/.npmrc"
RT="$PKG/resources/runtime/x64/primary-runtime/dependencies"
PATH="$RT/node/bin:$RT/python/bin:$PATH"
export PATH
NODE="$RT/node/bin/node"
PNPM="$PKG/resources/app.asar.unpacked/node_modules/pnpm/bin/pnpm.mjs"

if [ ! -x "$NODE" ] || [ ! -f "$PNPM" ]; then
  echo "便捷包缺少内置 node/pnpm，无法安装插件" >&2
  exit 1
fi
echo "将要安装："
list_plugins
cd "$PROFILE_DIR"
for tgz in "$BUNDLE"/*.tgz; do
  [ -e "$tgz" ] || continue
  echo "安装 $(basename "$tgz")"
  # --offline 只在 store 命中时成功；依赖闭包必须随插件一起进 store（打包脚本已如此处理）。
  # --config.cacheDir 指向包内缓存：离线解析 commander 这类范围依赖需要元数据，干净机器上没有全局缓存。
  "$NODE" "$PNPM" add --offline --store-dir "$BUNDLE/store" --config.cacheDir="$BUNDLE/cache" "$tgz"
done
echo "完成。重新启动便捷包使插件生效。"

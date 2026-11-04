#!/bin/sh
# 把本目录携带的插件装进同一个便捷包的当前激活 Profile（离线，不需要网络）。
# 用法：./install-plugins.sh [插件包目录]   默认指向 ./plugins-offline
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUNDLE="${1:-$DIR/plugins-offline}"

if [ ! -d "$BUNDLE" ]; then
  echo "找不到插件包目录：$BUNDLE" >&2
  exit 1
fi

# 定位目标便捷包：安装脚本既可能被放在包的顶层，也可能独立分发。
PKG="${DSH_NEXT_PACKAGE:-$DIR}"
if [ ! -x "$PKG/dsh-desktop-next" ] && [ ! -f "$PKG/dsh-desktop-next.exe" ]; then
  echo "未找到便捷包根目录（\$DSH_NEXT_PACKAGE 或本目录）" >&2
  exit 1
fi

export DSH_DESKTOP_NEXT_HOME="${DSH_DESKTOP_NEXT_HOME:-$PKG/home/data}"
export NPM_CONFIG_USERCONFIG="$PKG/.npmrc"
export NPM_CONFIG_STORE_DIR="$BUNDLE/store"
export NPM_CONFIG_CACHE="$BUNDLE/cache"

PROFILE_DIR="$DSH_DESKTOP_NEXT_HOME/profiles/desktop"
NODE="$PKG/resources/runtime/x64/primary-runtime/dependencies/node/bin/node"
PNPM="$PKG/resources/app.asar.unpacked/node_modules/pnpm/bin/pnpm.mjs"

if [ ! -x "$NODE" ] || [ ! -f "$PNPM" ]; then
  echo "便捷包缺少内置 node/pnpm，无法安装插件" >&2
  exit 1
fi
if [ ! -d "$PROFILE_DIR" ]; then
  echo "Profile 尚未创建：请先启动一次便捷包，再运行本脚本" >&2
  exit 1
fi

cd "$PROFILE_DIR"
for tgz in "$BUNDLE"/*.tgz; do
  [ -e "$tgz" ] || continue
  echo "安装 $(basename "$tgz")"
  # --offline 只在 store 命中时成功；依赖闭包必须随插件一起进 store（打包脚本已如此处理）。
  "$NODE" "$PNPM" add --offline --store-dir "$BUNDLE/store" "$tgz"
done
echo "完成。重新启动便捷包使插件生效。"

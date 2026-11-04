#!/bin/sh
# DSH NEXT 桌面版便捷启动器（Linux x64）
# 数据、缓存、插件全部留在本目录内，随包移动；清空用户数据用 ./DSH-NEXT-reset.sh
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export DSH_DESKTOP_NEXT_HOME="$DIR/home/data"
export NPM_CONFIG_USERCONFIG="$DIR/.npmrc"
mkdir -p "$DSH_DESKTOP_NEXT_HOME"
# pnpm 11 只从 pnpm-workspace.yaml（或命令行）读 storeDir/cacheDir；npmrc 与 NPM_CONFIG_* 都不生效。
# 用绝对路径写一份，界面里装插件就直接用包内离线仓库。
for profile in "$DSH_DESKTOP_NEXT_HOME"/profiles/*/; do
  [ -d "$profile" ] || continue
  cat > "$profile/pnpm-workspace.yaml" <<YAML
storeDir: $DIR/registry/store
cacheDir: $DIR/registry/cache
preferOffline: true
YAML
done
# 把包内运行时放进 PATH：插件、技能、MCP 服务里直接写 node / python3 / npm 也能命中包内的，
# 不必要求用户机器上装过 Node 或 Python。
RT="$DIR/resources/runtime/x64/primary-runtime/dependencies"
if [ -d "$RT" ]; then
  PATH="$RT/node/bin:$RT/python/bin:$PATH"
  export PATH
fi

exec "$DIR/dsh-desktop-next" "$@"

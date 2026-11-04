#!/bin/sh
# DSH NEXT 桌面版便捷启动器（Linux x64）
# 数据、缓存、插件全部留在本目录内，随包移动；清空用户数据用 ./DSH-NEXT-reset.sh
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export DSH_DESKTOP_NEXT_HOME="$DIR/home/data"
export NPM_CONFIG_USERCONFIG="$DIR/.npmrc"
mkdir -p "$DSH_DESKTOP_NEXT_HOME"
# store、缓存、运行时路径都由程序自己从包目录解析并写进当前进程环境（见 src/portable-environment.ts），
# 这里不写死任何路径：包被改名、移动或放在带空格的目录里都不会失效。
# 启动器只把包内解释器提前放进 PATH，方便插件、技能和 MCP 服务直接调用 node / python3。
RT="$DIR/resources/runtime/x64/primary-runtime/dependencies"
if [ -d "$RT" ]; then
  PATH="$RT/node/bin:$RT/python/bin:$PATH"
  export PATH
fi

exec "$DIR/dsh-desktop-next" "$@"

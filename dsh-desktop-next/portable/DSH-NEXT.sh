#!/bin/sh
# DSH NEXT 桌面版便捷启动器（Linux x64）
# 数据、缓存、插件全部留在本目录内，随包移动；清空用户数据用 ./DSH-NEXT-reset.sh
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export DSH_DESKTOP_NEXT_HOME="$DIR/home/data"
export NPM_CONFIG_USERCONFIG="$DIR/.npmrc"
export NPM_CONFIG_STORE_DIR="$DIR/registry/store"
export NPM_CONFIG_CACHE="$DIR/registry/cache"
export NPM_CONFIG_PREFER_OFFLINE="true"
mkdir -p "$DSH_DESKTOP_NEXT_HOME"
exec "$DIR/dsh-desktop-next" "$@"

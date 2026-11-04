#!/bin/sh
# 清空包内用户数据：会话、凭据、插件配置、缓存、Electron 存储。
# 保留：程序本体、运行时、预装插件与离线仓库。做完即可打包带走。
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "${1:-}" != "--yes" ]; then
  printf '将删除 %s/home 下全部用户数据，继续？[y/N] ' "$DIR"
  read -r answer
  case "$answer" in y|Y|yes|YES) ;; *) echo "已取消"; exit 0 ;; esac
fi
rm -rf "$DIR/home"
mkdir -p "$DIR/home"
echo "已清空用户数据：$DIR/home"

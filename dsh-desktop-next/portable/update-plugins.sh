#!/bin/sh
# 更新便捷包自带的插件库：重新解析、下载并写回 registry/（需要联网）
#
#   ./update-plugins.sh              # 按 registry/plugins.json 里的版本刷新
#   ./update-plugins.sh --latest     # 全部取最新版本
#   ./update-plugins.sh dsh-ops@1.2.3
#
# 只改本目录内的 registry/store、registry/cache 和 tarball，界面里装插件随后就用新库。
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RT="$DIR/resources/runtime/x64/primary-runtime/dependencies"
NODE="$RT/node/bin/node"
if [ ! -x "$NODE" ]; then
  echo "便捷包缺少内置 node，无法更新插件库：$NODE" >&2
  exit 1
fi
PATH="$RT/node/bin:$RT/python/bin:$PATH"
export PATH
exec "$NODE" "$DIR/tools/refresh-library.mjs" "$@"

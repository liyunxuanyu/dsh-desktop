#!/bin/sh
# 校验从 Release 下载的压缩包是否完整。
#
# 用法：
#   ./verify-download.sh                    # 校验当前目录下的文件，对照同目录 SHA256SUMS.txt
#   ./verify-download.sh <SHA256SUMS.txt>   # 指定校验和文件
#   ./verify-download.sh <SUMS> <目录>      # 指定校验和文件与待校验目录
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SUMS="${1:-$DIR/SHA256SUMS.txt}"
TARGET="${2:-$(dirname -- "$SUMS")}"

if [ ! -f "$SUMS" ]; then
  echo "找不到校验和文件：$SUMS" >&2
  echo "从 Release 页面一并下载 SHA256SUMS.txt。" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  HASH="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  HASH="shasum -a 256"
else
  echo "缺少 sha256sum 或 shasum，无法校验" >&2
  exit 1
fi

missing=0
failed=0
checked=0
while read -r expected name; do
  case "$expected" in ''|\#*) continue ;; esac
  [ -n "${name:-}" ] || continue
  file="$TARGET/$name"
  if [ ! -f "$file" ]; then
    echo "缺失  $name"
    missing=$((missing + 1))
    continue
  fi
  checked=$((checked + 1))
  actual=$($HASH "$file" | cut -d' ' -f1)
  if [ "$actual" = "$expected" ]; then
    echo "通过  $name"
  else
    echo "不匹配 $name"
    echo "      期望 $expected"
    echo "      实际 $actual"
    failed=$((failed + 1))
  fi
done < "$SUMS"

echo
# 只核对在场文件：通常只下载了其中一两个产物，未下载的不算失败。
if [ "$checked" -eq 0 ]; then
  echo "没有找到任何待校验文件（缺失 $missing 个）。" >&2
  exit 1
fi
if [ "$failed" -ne 0 ]; then
  echo "校验未通过：不匹配 $failed 个（已核对 $checked 个）。" >&2
  exit 1
fi
if [ "$missing" -ne 0 ]; then
  echo "已核对 $checked 个文件，全部通过；另有 $missing 个未下载，跳过。"
  exit 0
fi
echo "全部校验通过（$checked 个文件）。"
exit 0

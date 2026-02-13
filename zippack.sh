#!/bin/bash

# 用法: ./zippack.sh <输出zip路径> <文件1> [文件2] [文件3] ...
# 例如: ./zippack.sh myarchive file1.txt file2.txt
#       ./zippack.sh b/myarchive file1.txt file2.txt

# ── 参数检查 ──────────────────────────────────────────
if [ $# -lt 2 ]; then
    echo "用法: $0 <zip路径> <文件或目录...>"
    echo "例如: $0 myarchive file1.txt file2.txt"
    echo "      $0 b/myarchive file1.txt file2.txt"
    exit 1
fi

BASE_NAME="$1"
shift
FILES=("$@")

# ── 拆分路径：目录部分 + 文件名部分 ──────────────────
OUT_DIR=$(dirname "$BASE_NAME")   # b/xxxx -> b，无路径时为 .
OUT_NAME=$(basename "$BASE_NAME") # b/xxxx -> xxxx

# 如果输出目录不存在则自动创建
if [ ! -d "$OUT_DIR" ]; then
    mkdir -p "$OUT_DIR" || { echo "错误: 无法创建目录 $OUT_DIR"; exit 1; }
fi

# ── 检查文件是否存在 ──────────────────────────────────
for f in "${FILES[@]}"; do
    if [ ! -e "$f" ]; then
        echo "错误: 文件或目录不存在 -> $f"
        exit 1
    fi
done

# ── 自动寻找下一个可用版本号（取现有最大版本号 + 1）──
MAX_VERSION=0
for f in "${OUT_DIR}/${OUT_NAME}"_[0-9][0-9][0-9].zip; do
    # 如果没有匹配文件，glob 会原样返回字符串，跳过
    [ -f "$f" ] || continue

    # 提取文件名中的三位数字
    NUM="${f##*_}"    # 去掉最后一个 _ 之前的部分 -> 001.zip
    NUM="${NUM%.zip}" # 去掉 .zip -> 001
    NUM=$((10#$NUM))  # 强制按十进制解析（避免 008/009 被当成八进制）

    if [ "$NUM" -gt "$MAX_VERSION" ]; then
        MAX_VERSION="$NUM"
    fi
done

VERSION=$((MAX_VERSION + 1))

# 防止超出上限
if [ "$VERSION" -gt 999 ]; then
    echo "错误: 版本号已超过 999，请清理旧文件"
    exit 1
fi

VERSION_STR=$(printf "%03d" "$VERSION")
OUTPUT="${OUT_DIR}/${OUT_NAME}_${VERSION_STR}.zip"

# ── 清理 .DS_Store ────────────────────────────────────
echo "正在清理 .DS_Store ..."
DS_COUNT=0
while IFS= read -r -d '' ds; do
    rm "$ds"
    echo "  删除: $ds"
    DS_COUNT=$((DS_COUNT + 1))
done < <(find "${FILES[@]}" -name ".DS_Store" -print0 2>/dev/null)

if [ "$DS_COUNT" -eq 0 ]; then
    echo "  （没有找到 .DS_Store）"
else
    echo "  共删除 ${DS_COUNT} 个"
fi

# ── 执行打包 ──────────────────────────────────────────
echo "正在打包 -> $OUTPUT"
zip -r "$OUTPUT" "${FILES[@]}"

if [ $? -eq 0 ]; then
    echo "✅ 打包成功: $OUTPUT"
else
    echo "❌ 打包失败"
    exit 1
fi

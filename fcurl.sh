#!/bin/bash
# fcurl.sh - File Server Curl Helper for Linux/macOS
# Usage: ./fcurl.sh <URL>
# Example: ./fcurl.sh http://127.0.0.1:8080/shared/test.txt
#          ./fcurl.sh http://127.0.0.1:8080/shared/

if [ $# -lt 1 ]; then
    echo "Usage: $0 <URL>"
    echo "Example: $0 http://127.0.0.1:8080/shared/test.txt "
    exit 1
fi

URL="$1"

# 自动补全 http:// 协议头（如果没有的话）
if [[ ! "$URL" =~ ^https?:// ]]; then
    URL="http://${URL}"
fi

# 移除协议头，方便解析
URL_NO_PROTO="${URL#http://}"
URL_NO_PROTO="${URL_NO_PROTO#https://}"

# 解析 host:port 和 path
# 格式: host:port/path 或 host:port/ 或 host:port
HOST_PORT=$(echo "$URL_NO_PROTO" | cut -d'/' -f1)
PATH_PART=$(echo "$URL_NO_PROTO" | cut -s -d'/' -f2-)

if [ -z "$HOST_PORT" ]; then
    echo "Error: Invalid URL format"
    exit 1
fi

# 判断是文件还是目录
IS_DIR=0

# 检查是否以 / 结尾
if [[ "$URL" == */ ]]; then
    IS_DIR=1
fi

# 如果没有以 / 结尾，检查是否有文件扩展名
if [ $IS_DIR -eq 0 ]; then
    if [ -n "$PATH_PART" ]; then
        # Extract the last part of the path
        LAST_PART=$(basename "$PATH_PART")

        # Check if last part contains dot (has extension)
        if [[ ! "$LAST_PART" =~ \. ]]; then
            # No extension, treat as directory
            IS_DIR=1
            # Add trailing slash for consistency
            PATH_PART="${PATH_PART}/"
        fi
    else
        # PATH_PART 为空，说明只有 host:port 或 host:port/
        IS_DIR=1
    fi
fi

# Build sign URL by adding list/ or download/ prefix
if [ $IS_DIR -eq 1 ]; then
    SIGN_URL="http://${HOST_PORT}/list/${PATH_PART}"
else
    SIGN_URL="http://${HOST_PORT}/download/${PATH_PART}"
fi

# 获取脚本所在目录，用于找到 sign 程序
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Call sign and get signed URL
SIGNED_URL=$("${SCRIPT_DIR}/sign" "$SIGN_URL" 2>/dev/null | grep "^http://")

if [ -z "$SIGNED_URL" ]; then
    echo "Error: Failed to generate signed URL"
    exit 1
fi

# Execute curl
if [ $IS_DIR -eq 1 ]; then
    curl "$SIGNED_URL"
else
    curl -OJ "$SIGNED_URL"
fi

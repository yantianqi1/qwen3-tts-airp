#!/bin/bash

# Qwen3-TTS 停止脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo ""
echo "停止 Qwen3-TTS 服务..."
echo ""

# 停止后端
if [ -f "$PROJECT_DIR/logs/backend.pid" ]; then
    PID=$(cat "$PROJECT_DIR/logs/backend.pid")
    if ps -p $PID > /dev/null 2>&1; then
        kill $PID
        echo -e "${GREEN}后端服务已停止 (PID: $PID)${NC}"
    else
        echo "后端服务未运行"
    fi
    rm -f "$PROJECT_DIR/logs/backend.pid"
else
    echo "未找到后端 PID 文件"
fi

# 停止前端
if [ -f "$PROJECT_DIR/logs/frontend.pid" ]; then
    PID=$(cat "$PROJECT_DIR/logs/frontend.pid")
    if ps -p $PID > /dev/null 2>&1; then
        kill $PID
        echo -e "${GREEN}前端服务已停止 (PID: $PID)${NC}"
    else
        echo "前端服务未运行"
    fi
    rm -f "$PROJECT_DIR/logs/frontend.pid"
else
    echo "未找到前端 PID 文件"
fi

echo ""
echo "服务已全部停止"
echo ""

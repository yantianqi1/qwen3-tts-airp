#!/bin/bash

# Qwen3-TTS 启动脚本

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}=========================================="
echo "  Qwen3-TTS 服务启动"
echo "==========================================${NC}"
echo ""

# 配置
BACKEND_PORT=${BACKEND_PORT:-8000}
FRONTEND_PORT=${FRONTEND_PORT:-3000}
MODEL=${QWEN_TTS_MODEL:-"Qwen/Qwen3-TTS-12Hz-0.6B-Base"}
DEVICE=${QWEN_TTS_DEVICE:-"cpu"}

echo "配置信息:"
echo "  模型: $MODEL"
echo "  设备: $DEVICE"
echo "  后端端口: $BACKEND_PORT"
echo "  前端端口: $FRONTEND_PORT"
echo ""

# 激活虚拟环境
if [ -f "$PROJECT_DIR/venv/bin/activate" ]; then
    source "$PROJECT_DIR/venv/bin/activate"
else
    echo -e "${YELLOW}警告: 未找到虚拟环境，请先运行 install.sh${NC}"
    exit 1
fi

# 创建日志目录
mkdir -p "$PROJECT_DIR/logs"

# 检查是否已经在运行
if [ -f "$PROJECT_DIR/logs/backend.pid" ]; then
    OLD_PID=$(cat "$PROJECT_DIR/logs/backend.pid")
    if ps -p $OLD_PID > /dev/null 2>&1; then
        echo -e "${YELLOW}后端服务已在运行 (PID: $OLD_PID)${NC}"
        echo "如需重启，请先运行 stop.sh"
        exit 1
    fi
fi

# 启动后端
echo -e "${GREEN}启动后端服务...${NC}"
cd "$PROJECT_DIR"
export QWEN_TTS_MODEL="$MODEL"
export QWEN_TTS_DEVICE="$DEVICE"

nohup python -m uvicorn backend.main:app \
    --host 0.0.0.0 \
    --port $BACKEND_PORT \
    > "$PROJECT_DIR/logs/backend.log" 2>&1 &

BACKEND_PID=$!
echo $BACKEND_PID > "$PROJECT_DIR/logs/backend.pid"
echo "后端 PID: $BACKEND_PID"

# 等待后端启动
echo "等待后端启动..."
sleep 3

# 检查后端是否启动成功
if ! ps -p $BACKEND_PID > /dev/null 2>&1; then
    echo -e "${YELLOW}后端启动失败，查看日志:${NC}"
    tail -20 "$PROJECT_DIR/logs/backend.log"
    exit 1
fi

# 启动前端 (开发模式) 或使用静态文件
if [ -d "$PROJECT_DIR/frontend/dist" ]; then
    echo -e "${GREEN}使用构建好的前端...${NC}"
    echo "前端已构建，通过后端服务访问"
else
    echo -e "${GREEN}启动前端开发服务器...${NC}"
    cd "$PROJECT_DIR/frontend"
    nohup npm run dev -- --host 0.0.0.0 --port $FRONTEND_PORT \
        > "$PROJECT_DIR/logs/frontend.log" 2>&1 &

    FRONTEND_PID=$!
    echo $FRONTEND_PID > "$PROJECT_DIR/logs/frontend.pid"
    echo "前端 PID: $FRONTEND_PID"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "  服务启动成功!"
echo "==========================================${NC}"
echo ""
echo "访问地址:"
echo -e "  后端 API: ${CYAN}http://localhost:$BACKEND_PORT${NC}"
echo -e "  API 文档: ${CYAN}http://localhost:$BACKEND_PORT/docs${NC}"
if [ ! -d "$PROJECT_DIR/frontend/dist" ]; then
    echo -e "  前端界面: ${CYAN}http://localhost:$FRONTEND_PORT${NC}"
fi
echo ""
echo "日志文件:"
echo "  后端: $PROJECT_DIR/logs/backend.log"
echo "  前端: $PROJECT_DIR/logs/frontend.log"
echo ""
echo -e "${YELLOW}注意: 首次启动需要下载模型，请查看后端日志${NC}"
echo "  tail -f $PROJECT_DIR/logs/backend.log"
echo ""

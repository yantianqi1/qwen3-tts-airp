#!/bin/bash

# Qwen3-TTS 完全清理脚本
# 清理所有环境、缓存、模型和占用

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo -e "${RED}=========================================="
echo "  Qwen3-TTS 完全清理脚本"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}警告: 此操作将删除以下内容:${NC}"
echo "  - 运行中的服务进程"
echo "  - Python 虚拟环境 (venv/)"
echo "  - Node.js 依赖 (node_modules/)"
echo "  - 前端构建文件 (dist/)"
echo "  - 生成的音频文件 (audio_output/)"
echo "  - 日志文件 (logs/)"
echo "  - Hugging Face 模型缓存 (~/.cache/huggingface/)"
echo ""

# 确认操作
read -p "确定要清理吗? (输入 yes 确认): " confirm
if [ "$confirm" != "yes" ]; then
    echo "已取消"
    exit 0
fi

echo ""

# 1. 停止运行中的服务
echo -e "${CYAN}[1/7] 停止运行中的服务...${NC}"

# 停止后端
if [ -f "$PROJECT_DIR/logs/backend.pid" ]; then
    PID=$(cat "$PROJECT_DIR/logs/backend.pid" 2>/dev/null)
    if [ -n "$PID" ] && ps -p $PID > /dev/null 2>&1; then
        kill $PID 2>/dev/null || true
        echo "  已停止后端服务 (PID: $PID)"
    fi
fi

# 停止前端
if [ -f "$PROJECT_DIR/logs/frontend.pid" ]; then
    PID=$(cat "$PROJECT_DIR/logs/frontend.pid" 2>/dev/null)
    if [ -n "$PID" ] && ps -p $PID > /dev/null 2>&1; then
        kill $PID 2>/dev/null || true
        echo "  已停止前端服务 (PID: $PID)"
    fi
fi

# 强制杀死可能残留的进程
pkill -f "uvicorn backend.main:app" 2>/dev/null || true
pkill -f "vite.*qwen3-tts" 2>/dev/null || true

echo -e "${GREEN}  服务已停止${NC}"

# 2. 清理 Python 虚拟环境
echo -e "${CYAN}[2/7] 清理 Python 虚拟环境...${NC}"
if [ -d "$PROJECT_DIR/venv" ]; then
    rm -rf "$PROJECT_DIR/venv"
    echo -e "${GREEN}  已删除 venv/${NC}"
else
    echo "  venv/ 不存在，跳过"
fi

# 3. 清理 Node.js 依赖
echo -e "${CYAN}[3/7] 清理 Node.js 依赖...${NC}"
if [ -d "$PROJECT_DIR/frontend/node_modules" ]; then
    rm -rf "$PROJECT_DIR/frontend/node_modules"
    echo -e "${GREEN}  已删除 frontend/node_modules/${NC}"
else
    echo "  node_modules/ 不存在，跳过"
fi

# 清理 package-lock
if [ -f "$PROJECT_DIR/frontend/package-lock.json" ]; then
    rm -f "$PROJECT_DIR/frontend/package-lock.json"
    echo -e "${GREEN}  已删除 package-lock.json${NC}"
fi

# 4. 清理前端构建文件
echo -e "${CYAN}[4/7] 清理前端构建文件...${NC}"
if [ -d "$PROJECT_DIR/frontend/dist" ]; then
    rm -rf "$PROJECT_DIR/frontend/dist"
    echo -e "${GREEN}  已删除 frontend/dist/${NC}"
else
    echo "  dist/ 不存在，跳过"
fi

# 5. 清理生成的音频
echo -e "${CYAN}[5/7] 清理生成的音频文件...${NC}"
if [ -d "$PROJECT_DIR/audio_output" ]; then
    count=$(find "$PROJECT_DIR/audio_output" -name "*.wav" 2>/dev/null | wc -l)
    rm -rf "$PROJECT_DIR/audio_output"/*
    echo -e "${GREEN}  已删除 $count 个音频文件${NC}"
else
    echo "  audio_output/ 不存在，跳过"
fi

# 6. 清理日志
echo -e "${CYAN}[6/7] 清理日志文件...${NC}"
if [ -d "$PROJECT_DIR/logs" ]; then
    rm -rf "$PROJECT_DIR/logs"
    echo -e "${GREEN}  已删除 logs/${NC}"
else
    echo "  logs/ 不存在，跳过"
fi

# 7. 清理 Hugging Face 模型缓存
echo -e "${CYAN}[7/7] 清理 Hugging Face 模型缓存...${NC}"

HF_CACHE_DIR="${HF_HOME:-$HOME/.cache/huggingface}"
QWEN_TTS_CACHE="$HF_CACHE_DIR/hub/models--Qwen--Qwen3-TTS*"

# 检查缓存大小
if ls -d $QWEN_TTS_CACHE 2>/dev/null | head -1 > /dev/null; then
    cache_size=$(du -sh $HF_CACHE_DIR/hub/models--Qwen--Qwen3-TTS* 2>/dev/null | cut -f1 | head -1)
    echo -e "  找到模型缓存，大小约: ${YELLOW}$cache_size${NC}"

    read -p "  是否删除模型缓存? (y/n): " del_cache
    if [ "$del_cache" = "y" ] || [ "$del_cache" = "Y" ]; then
        rm -rf $QWEN_TTS_CACHE
        echo -e "${GREEN}  已删除模型缓存${NC}"
    else
        echo "  保留模型缓存"
    fi
else
    echo "  未找到 Qwen3-TTS 模型缓存"
fi

# 清理 Python 缓存
echo ""
echo -e "${CYAN}清理 Python 缓存...${NC}"
find "$PROJECT_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$PROJECT_DIR" -type f -name "*.pyc" -delete 2>/dev/null || true
echo -e "${GREEN}  已清理 Python 缓存${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo "  清理完成!"
echo "==========================================${NC}"
echo ""
echo "已清理内容:"
echo "  - 服务进程"
echo "  - Python 虚拟环境"
echo "  - Node.js 依赖"
echo "  - 前端构建"
echo "  - 音频文件"
echo "  - 日志文件"
echo "  - Python 缓存"
echo ""
echo "如需重新安装，请运行: ./scripts/install.sh"
echo ""

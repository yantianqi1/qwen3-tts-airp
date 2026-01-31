#!/bin/bash

# Qwen3-TTS 一键安装脚本 (Ubuntu)
# 适用于 Ubuntu 20.04/22.04

set -e

echo "=========================================="
echo "  Qwen3-TTS 整合包安装脚本"
echo "  适用于 Ubuntu 20.04/22.04"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}警告: 建议使用普通用户运行此脚本${NC}"
fi

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "项目目录: $PROJECT_DIR"
echo ""

# 1. 系统依赖
echo -e "${GREEN}[1/5] 安装系统依赖...${NC}"
sudo apt-get update
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    libsndfile1 \
    ffmpeg \
    git \
    curl

# 检查 Node.js 版本
NODE_VERSION=$(node -v 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
    echo -e "${YELLOW}Node.js 版本过低，正在安装新版本...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo ""

# 2. Python 虚拟环境
echo -e "${GREEN}[2/5] 创建 Python 虚拟环境...${NC}"
cd "$PROJECT_DIR"

if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate

echo ""

# 3. 安装 Python 依赖
echo -e "${GREEN}[3/5] 安装 Python 依赖...${NC}"
pip install --upgrade pip
pip install -r backend/requirements.txt

echo ""

# 4. 安装前端依赖
echo -e "${GREEN}[4/5] 安装前端依赖...${NC}"
cd "$PROJECT_DIR/frontend"
npm install

echo ""

# 5. 构建前端
echo -e "${GREEN}[5/5] 构建前端...${NC}"
npm run build

echo ""
echo "=========================================="
echo -e "${GREEN}安装完成!${NC}"
echo "=========================================="
echo ""
echo "使用方法:"
echo "  启动服务: ./scripts/start.sh"
echo "  停止服务: ./scripts/stop.sh"
echo ""
echo "首次启动会下载模型 (~1.5GB)，请耐心等待"
echo ""

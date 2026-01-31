# Qwen3-TTS 语音合成服务

基于阿里巴巴 Qwen3-TTS-0.6B 模型的文本转语音服务，支持 CPU 运行。

## 系统要求

- **操作系统**: Ubuntu 20.04 / 22.04
- **CPU**: 4 核心以上（推荐 8 核心+）
- **内存**: 8GB 以上（推荐 12GB+）
- **磁盘**: 10GB 可用空间（模型约 1.5GB）

## 快速开始

### 1. 一键安装

```bash
cd qwen3-tts-server
chmod +x scripts/*.sh
./scripts/install.sh
```

安装过程会自动:
- 安装系统依赖 (Python, Node.js, ffmpeg 等)
- 创建 Python 虚拟环境
- 安装 Python 和前端依赖
- 构建前端

### 2. 启动服务

```bash
./scripts/start.sh
```

首次启动会自动从 Hugging Face 下载模型 (~1.5GB)，请耐心等待。

### 3. 访问服务

- 前端界面: http://localhost:3000
- 后端 API: http://localhost:8000
- API 文档: http://localhost:8000/docs

### 4. 停止服务

```bash
./scripts/stop.sh
```

## 目录结构

```
qwen3-tts-server/
├── backend/              # FastAPI 后端
│   ├── main.py          # 主程序
│   └── requirements.txt # Python 依赖
├── frontend/            # Vue 3 前端
│   ├── src/
│   │   ├── App.vue     # 主组件
│   │   └── main.js
│   ├── package.json
│   └── vite.config.js
├── scripts/             # 脚本
│   ├── install.sh      # 安装脚本
│   ├── start.sh        # 启动脚本
│   └── stop.sh         # 停止脚本
├── audio_output/        # 生成的音频文件
└── logs/                # 日志文件
```

## 配置选项

通过环境变量配置:

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `QWEN_TTS_MODEL` | `Qwen/Qwen3-TTS-12Hz-0.6B-Base` | 模型名称 |
| `QWEN_TTS_DEVICE` | `cpu` | 运行设备 (cpu/cuda) |
| `BACKEND_PORT` | `8000` | 后端端口 |
| `FRONTEND_PORT` | `3000` | 前端端口 |

示例:
```bash
# 使用 GPU
export QWEN_TTS_DEVICE="cuda:0"
export QWEN_TTS_MODEL="Qwen/Qwen3-TTS-12Hz-1.7B-Base"
./scripts/start.sh
```

## API 接口

### POST /api/tts

文本转语音

**请求体:**
```json
{
  "text": "你好，这是一段测试文本",
  "language": "Chinese"
}
```

**响应:**
```json
{
  "success": true,
  "message": "语音生成成功",
  "audio_url": "/audio/abc12345.wav",
  "audio_id": "abc12345",
  "duration": 2.5
}
```

### GET /api/languages

获取支持的语言列表

### GET /api/status

获取服务状态

## 支持的语言

- 中文 (Chinese)
- 英语 (English)
- 日语 (Japanese)
- 韩语 (Korean)
- 德语 (German)
- 法语 (French)
- 俄语 (Russian)
- 葡萄牙语 (Portuguese)
- 西班牙语 (Spanish)
- 意大利语 (Italian)

## 常见问题

### Q: 模型下载慢怎么办?

可以使用国内镜像:
```bash
export HF_ENDPOINT=https://hf-mirror.com
./scripts/start.sh
```

### Q: 内存不足怎么办?

- 确保使用 0.6B 版本模型
- 关闭其他占用内存的程序
- 增加 swap 空间

### Q: 生成速度慢怎么办?

CPU 模式下生成速度较慢是正常的。如需更快速度:
- 使用 GPU 运行
- 减少输入文本长度
- 升级 CPU

## 升级到更大模型

如需使用 1.7B 版本获得更好效果:

```bash
export QWEN_TTS_MODEL="Qwen/Qwen3-TTS-12Hz-1.7B-Base"
./scripts/start.sh
```

注意: 1.7B 版本需要至少 8GB 内存，推荐使用 GPU。

## License

MIT License

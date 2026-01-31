"""
Qwen3-TTS Server - FastAPI 后端服务
支持 CPU 运行，适用于 Ubuntu 服务器部署
"""

import os
import uuid
import asyncio
from pathlib import Path
from typing import Optional
from contextlib import asynccontextmanager

import torch
import soundfile as sf
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

# 配置
MODEL_NAME = os.getenv("QWEN_TTS_MODEL", "Qwen/Qwen3-TTS-12Hz-0.6B-Base")
DEVICE = os.getenv("QWEN_TTS_DEVICE", "cpu")
OUTPUT_DIR = Path(__file__).parent.parent / "audio_output"
OUTPUT_DIR.mkdir(exist_ok=True)

# 全局模型实例
tts_model = None


def get_torch_dtype():
    """根据设备选择合适的数据类型"""
    if DEVICE == "cpu":
        return torch.float32
    return torch.bfloat16


def load_model():
    """加载 TTS 模型"""
    global tts_model

    print(f"正在加载模型: {MODEL_NAME}")
    print(f"运行设备: {DEVICE}")

    # 设置 CPU 线程数
    if DEVICE == "cpu":
        cpu_count = os.cpu_count() or 4
        threads = max(1, cpu_count - 2)  # 留 2 个核心给系统
        torch.set_num_threads(threads)
        print(f"CPU 线程数: {threads}")

    try:
        from qwen_tts import Qwen3TTSModel

        load_kwargs = {
            "device_map": DEVICE,
            "torch_dtype": get_torch_dtype(),
        }

        # GPU 时启用 flash attention
        if DEVICE != "cpu":
            load_kwargs["attn_implementation"] = "flash_attention_2"

        tts_model = Qwen3TTSModel.from_pretrained(MODEL_NAME, **load_kwargs)
        print("模型加载完成!")

    except Exception as e:
        print(f"模型加载失败: {e}")
        raise


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时加载模型
    load_model()
    yield
    # 关闭时清理
    global tts_model
    tts_model = None


app = FastAPI(
    title="Qwen3-TTS Server",
    description="基于 Qwen3-TTS 的文本转语音服务",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS 配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 静态文件服务
app.mount("/audio", StaticFiles(directory=str(OUTPUT_DIR)), name="audio")


# 请求模型
class TTSRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=5000, description="要转换的文本")
    language: str = Field(default="Chinese", description="语言")
    speed: float = Field(default=1.0, ge=0.5, le=2.0, description="语速")


class TTSResponse(BaseModel):
    success: bool
    message: str
    audio_url: Optional[str] = None
    audio_id: Optional[str] = None
    duration: Optional[float] = None


# 支持的语言列表
SUPPORTED_LANGUAGES = [
    "Chinese", "English", "Japanese", "Korean",
    "German", "French", "Russian", "Portuguese",
    "Spanish", "Italian"
]


@app.get("/")
async def root():
    """健康检查"""
    return {
        "status": "running",
        "model": MODEL_NAME,
        "device": DEVICE,
    }


@app.get("/api/languages")
async def get_languages():
    """获取支持的语言列表"""
    return {"languages": SUPPORTED_LANGUAGES}


@app.get("/api/status")
async def get_status():
    """获取服务状态"""
    return {
        "model_loaded": tts_model is not None,
        "model_name": MODEL_NAME,
        "device": DEVICE,
        "torch_threads": torch.get_num_threads() if DEVICE == "cpu" else None,
    }


@app.post("/api/tts", response_model=TTSResponse)
async def text_to_speech(request: TTSRequest):
    """文本转语音 API"""

    if tts_model is None:
        raise HTTPException(status_code=503, detail="模型尚未加载完成")

    if request.language not in SUPPORTED_LANGUAGES:
        raise HTTPException(
            status_code=400,
            detail=f"不支持的语言: {request.language}，支持的语言: {SUPPORTED_LANGUAGES}"
        )

    try:
        # 生成唯一文件名
        audio_id = str(uuid.uuid4())[:8]
        output_path = OUTPUT_DIR / f"{audio_id}.wav"

        # 在线程池中运行 TTS（避免阻塞）
        loop = asyncio.get_event_loop()
        wavs, sr = await loop.run_in_executor(
            None,
            lambda: tts_model.synthesize(
                text=request.text,
                language=request.language,
            )
        )

        # 保存音频
        sf.write(str(output_path), wavs[0], sr)

        # 计算时长
        duration = len(wavs[0]) / sr

        return TTSResponse(
            success=True,
            message="语音生成成功",
            audio_url=f"/audio/{audio_id}.wav",
            audio_id=audio_id,
            duration=round(duration, 2),
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"语音生成失败: {str(e)}")


@app.delete("/api/audio/{audio_id}")
async def delete_audio(audio_id: str):
    """删除音频文件"""
    audio_path = OUTPUT_DIR / f"{audio_id}.wav"
    if audio_path.exists():
        audio_path.unlink()
        return {"success": True, "message": "文件已删除"}
    raise HTTPException(status_code=404, detail="文件不存在")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

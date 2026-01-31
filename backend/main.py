"""
Qwen3-TTS Server - FastAPI 后端服务
基于 0.6B-Base 模型，支持声音克隆
"""

import os
import uuid
import asyncio
from pathlib import Path
from typing import Optional
from contextlib import asynccontextmanager

import torch
import soundfile as sf
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

# 配置 - 使用 Base 模型，支持声音克隆
MODEL_NAME = os.getenv("QWEN_TTS_MODEL", "Qwen/Qwen3-TTS-12Hz-0.6B-Base")
DEVICE = os.getenv("QWEN_TTS_DEVICE", "cpu")
OUTPUT_DIR = Path(__file__).parent.parent / "audio_output"
OUTPUT_DIR.mkdir(exist_ok=True)
FRONTEND_DIR = Path(__file__).parent.parent / "frontend" / "dist"
REF_AUDIO_DIR = Path(__file__).parent.parent / "ref_audio"
REF_AUDIO_DIR.mkdir(exist_ok=True)

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
    description="基于 Qwen3-TTS 的文本转语音服务，支持声音克隆",
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
app.mount("/ref_audio", StaticFiles(directory=str(REF_AUDIO_DIR)), name="ref_audio")

# 前端静态文件服务
if FRONTEND_DIR.exists():
    assets_dir = FRONTEND_DIR / "assets"
    if assets_dir.exists():
        app.mount("/assets", StaticFiles(directory=str(assets_dir)), name="assets")


# 响应模型
class TTSResponse(BaseModel):
    success: bool
    message: str
    audio_url: Optional[str] = None
    audio_id: Optional[str] = None
    duration: Optional[float] = None


class RefAudioResponse(BaseModel):
    success: bool
    message: str
    ref_id: Optional[str] = None
    filename: Optional[str] = None


# 支持的语言列表
SUPPORTED_LANGUAGES = [
    "Chinese", "English", "Japanese", "Korean",
    "German", "French", "Russian", "Portuguese",
    "Spanish", "Italian"
]


@app.get("/")
async def root():
    """返回前端页面或健康检查"""
    if FRONTEND_DIR.exists():
        index_file = FRONTEND_DIR / "index.html"
        if index_file.exists():
            return FileResponse(index_file)
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


@app.get("/api/ref_audios")
async def get_ref_audios():
    """获取已上传的参考音频列表"""
    audios = []
    for f in REF_AUDIO_DIR.glob("*.wav"):
        # 尝试读取对应的文本文件
        txt_file = f.with_suffix(".txt")
        ref_text = ""
        if txt_file.exists():
            ref_text = txt_file.read_text(encoding="utf-8").strip()
        audios.append({
            "id": f.stem,
            "filename": f.name,
            "ref_text": ref_text,
        })
    return {"audios": audios}


@app.post("/api/upload_ref_audio", response_model=RefAudioResponse)
async def upload_ref_audio(
    file: UploadFile = File(...),
    ref_text: str = Form(...),
):
    """上传参考音频"""
    if not file.filename.endswith((".wav", ".mp3", ".flac", ".m4a")):
        raise HTTPException(status_code=400, detail="仅支持 wav/mp3/flac/m4a 格式")

    try:
        # 生成唯一 ID
        ref_id = str(uuid.uuid4())[:8]

        # 保存音频文件
        audio_path = REF_AUDIO_DIR / f"{ref_id}.wav"
        content = await file.read()

        # 如果不是 wav 格式，需要转换（简单起见先直接保存）
        with open(audio_path, "wb") as f:
            f.write(content)

        # 保存参考文本
        txt_path = REF_AUDIO_DIR / f"{ref_id}.txt"
        txt_path.write_text(ref_text, encoding="utf-8")

        return RefAudioResponse(
            success=True,
            message="参考音频上传成功",
            ref_id=ref_id,
            filename=file.filename,
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


@app.delete("/api/ref_audio/{ref_id}")
async def delete_ref_audio(ref_id: str):
    """删除参考音频"""
    audio_path = REF_AUDIO_DIR / f"{ref_id}.wav"
    txt_path = REF_AUDIO_DIR / f"{ref_id}.txt"

    if audio_path.exists():
        audio_path.unlink()
    if txt_path.exists():
        txt_path.unlink()

    return {"success": True, "message": "参考音频已删除"}


@app.post("/api/tts", response_model=TTSResponse)
async def text_to_speech(
    text: str = Form(...),
    language: str = Form(default="Chinese"),
    ref_audio_id: str = Form(...),
):
    """文本转语音 API - 使用声音克隆"""

    if tts_model is None:
        raise HTTPException(status_code=503, detail="模型尚未加载完成")

    if language not in SUPPORTED_LANGUAGES:
        raise HTTPException(
            status_code=400,
            detail=f"不支持的语言: {language}，支持的语言: {SUPPORTED_LANGUAGES}"
        )

    # 查找参考音频
    ref_audio_path = REF_AUDIO_DIR / f"{ref_audio_id}.wav"
    ref_txt_path = REF_AUDIO_DIR / f"{ref_audio_id}.txt"

    if not ref_audio_path.exists():
        raise HTTPException(status_code=400, detail="参考音频不存在，请先上传参考音频")

    ref_text = ""
    if ref_txt_path.exists():
        ref_text = ref_txt_path.read_text(encoding="utf-8").strip()

    if not ref_text:
        raise HTTPException(status_code=400, detail="参考音频缺少对应文本")

    try:
        # 生成唯一文件名
        audio_id = str(uuid.uuid4())[:8]
        output_path = OUTPUT_DIR / f"{audio_id}.wav"

        # 在线程池中运行 TTS（避免阻塞）
        loop = asyncio.get_event_loop()
        wavs, sr = await loop.run_in_executor(
            None,
            lambda: tts_model.generate_voice_clone(
                text=text,
                language=language,
                ref_audio=str(ref_audio_path),
                ref_text=ref_text,
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
    uvicorn.run(app, host="0.0.0.0", port=8019)

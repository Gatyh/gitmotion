# =============================================================================
# 3DTexel Motion Generator - RunPod Serverless
# Uses HY-Motion-1.0 FULL with Qwen3-8B FULL for text-to-motion generation
# =============================================================================

FROM runpod/worker-comfyui:5.5.1-base

# -----------------------------------------------------------------------------
# Install ComfyUI-HY-Motion1 custom node
# -----------------------------------------------------------------------------
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/jtydhr88/ComfyUI-HY-Motion1.git && \
    cd ComfyUI-HY-Motion1 && \
    pip install -r requirements.txt

# -----------------------------------------------------------------------------
# Install FBX SDK for FBX export (optional but recommended)
# -----------------------------------------------------------------------------
RUN pip install fbxsdkpy || echo "fbxsdkpy installation failed, FBX export will use fallback"

# -----------------------------------------------------------------------------
# Download HY-Motion-1.0 FULL (NOT Lite)
# -----------------------------------------------------------------------------
RUN mkdir -p /comfyui/models/HY-Motion/ckpts/HY-Motion-1.0 && \
    cd /comfyui/models/HY-Motion/ckpts/HY-Motion-1.0 && \
    wget -O config.json "https://huggingface.co/tencent/HY-Motion-1.0/resolve/main/config.json" && \
    wget -O diffusion_pytorch_model.safetensors "https://huggingface.co/tencent/HY-Motion-1.0/resolve/main/diffusion_pytorch_model.safetensors"

# -----------------------------------------------------------------------------
# Download Qwen3-8B FULL (NOT 1.7B or quantized)
# -----------------------------------------------------------------------------
RUN mkdir -p /comfyui/models/HY-Motion/ckpts/Qwen3-8B && \
    cd /comfyui/models/HY-Motion/ckpts/Qwen3-8B && \
    wget -O config.json "https://huggingface.co/Qwen/Qwen3-8B/resolve/main/config.json" && \
    wget -O generation_config.json "https://huggingface.co/Qwen/Qwen3-8B/resolve/main/generation_config.json" && \
    wget -O model-00001-of-00004.safetensors "https://huggingface.co/Qwen/Qwen3-8B/resolve/main/model-00001-of-00004.safetensors" && \
    wget -O model-00002-of-00004.safetensors "https://huggingface.co/Qwen/Qwen3-8B/resolve/main/model-00002-of-00004.safetensors" && \
    wget -O model-00003-of-00004.safetensors "https://huggingface.co/Qwen/Qwen3-8B/resolve/main/model-00003-of-00004.safetensors" && \
    wget -O model-00004-of-00004.safetensors "https://huggingface.co/Qwen/Qwen3-8B/resolve/main/model-00004-of-00004.safetensors" && \
    wget -O model.safetensors.index.json "https://huggingface.co/Qwen/Qwen3-8B/resolve/main/model.safetensors.index.json" && \
    wget -O tokenizer.json "https://huggingface.co/Qwen/Qwen3-8B/resolve/main/tokenizer.json" && \
    wget -O tokenizer_config.json "https://huggingface.co/Qwen/Qwen3-8B/resolve/main/tokenizer_config.json" && \
    wget -O vocab.json "https://huggingface.co/Qwen/Qwen3-8B/resolve/main/vocab.json" && \
    wget -O merges.txt "https://huggingface.co/Qwen/Qwen3-8B/resolve/main/merges.txt"

# -----------------------------------------------------------------------------
# Download SMPL body model for motion generation
# -----------------------------------------------------------------------------
RUN mkdir -p /comfyui/models/HY-Motion/body_models && \
    cd /comfyui/models/HY-Motion/body_models && \
    wget -O smpl_neutral.pkl "https://huggingface.co/tencent/HY-Motion-1.0/resolve/main/body_models/smpl/SMPL_NEUTRAL.pkl"

# =============================================================================
# Configuration finale
# =============================================================================

ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
WORKDIR /comfyui

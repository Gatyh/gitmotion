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
# Install FBX SDK and huggingface-cli for model downloads
# -----------------------------------------------------------------------------
RUN pip install huggingface-hub[cli] && \
    pip install fbxsdkpy || echo "fbxsdkpy installation failed, FBX export will use fallback"

# -----------------------------------------------------------------------------
# Download HY-Motion-1.0 FULL (NOT Lite)
# -----------------------------------------------------------------------------
RUN mkdir -p /comfyui/models/HY-Motion/ckpts/tencent/HY-Motion-1.0 && \
    cd /comfyui/models/HY-Motion/ckpts/tencent/HY-Motion-1.0 && \
    wget -O config.yml "https://huggingface.co/tencent/HY-Motion-1.0/resolve/main/HY-Motion-1.0/config.yml" && \
    wget -O latest.ckpt "https://huggingface.co/tencent/HY-Motion-1.0/resolve/main/HY-Motion-1.0/latest.ckpt"

# -----------------------------------------------------------------------------
# Download CLIP text encoder
# -----------------------------------------------------------------------------
RUN huggingface-cli download openai/clip-vit-large-patch14 \
    --local-dir /comfyui/models/HY-Motion/ckpts/clip-vit-large-patch14

# -----------------------------------------------------------------------------
# Download Qwen3-8B FULL (NOT 1.7B or quantized)
# -----------------------------------------------------------------------------
RUN huggingface-cli download Qwen/Qwen3-8B \
    --local-dir /comfyui/models/HY-Motion/ckpts/Qwen3-8B

# =============================================================================
# Custom handler - scans /output/ and returns NPZ/FBX files as base64
# Le fichier handler.py DOIT être dans le même dossier que ce Dockerfile
# =============================================================================
COPY handler.py /handler.py

# =============================================================================
# Configuration finale
# =============================================================================

ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
ENV USE_HF_MODELS=1
WORKDIR /comfyui

# Override the default handler to use our custom one
CMD ["python", "-u", "/handler.py"]

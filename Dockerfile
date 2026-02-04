# =============================================================================
# ComfyUI Docker - 3DTexel HY-Motion Only
# =============================================================================
# Workflow: workflow_api_hymotion.json - HY-Motion animation (GLB export)
# GPU requis: 24GB+ VRAM pour modèles FULL
# =============================================================================

FROM runpod/worker-comfyui:5.5.1-base

# =============================================================================
# HY-Motion Animation - FULL QUALITY
# =============================================================================

# ComfyUI-HY-Motion1 custom node
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/jtydhr88/ComfyUI-HY-Motion1.git && \
    cd ComfyUI-HY-Motion1 && \
    pip install -r requirements.txt

# Dépendances supplémentaires pour HY-Motion
RUN pip install accelerate bitsandbytes torchdiffeq

# Structure des modèles HY-Motion (selon README officiel)
# ckpts/tencent/HY-Motion-1.0/config.yml
# ckpts/clip-vit-large-patch14/
# ckpts/Qwen3-8B/
RUN mkdir -p /comfyui/models/HY-Motion/ckpts/tencent

# HY-Motion-1.0 FULL - télécharger uniquement le sous-dossier HY-Motion-1.0
RUN huggingface-cli download tencent/HY-Motion-1.0 \
    --include "HY-Motion-1.0/*" \
    --local-dir /tmp/hy-motion-download && \
    mv /tmp/hy-motion-download/HY-Motion-1.0 /comfyui/models/HY-Motion/ckpts/tencent/HY-Motion-1.0 && \
    rm -rf /tmp/hy-motion-download

# CLIP model requis par HY-Motion (directement dans ckpts/)
RUN huggingface-cli download openai/clip-vit-large-patch14 \
    --local-dir /comfyui/models/HY-Motion/ckpts/clip-vit-large-patch14

# Qwen3-8B LLM FULL (directement dans ckpts/)
RUN huggingface-cli download Qwen/Qwen3-8B \
    --local-dir /comfyui/models/HY-Motion/ckpts/Qwen3-8B

# =============================================================================
# Custom node pour exposer NPZ via websocket
# =============================================================================

# Copier le custom node qui wrappe SaveNPZ pour exposer l'output
COPY custom_motion_save.py /comfyui/custom_nodes/custom_motion_save.py

# =============================================================================
# Configuration finale
# =============================================================================

ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
ENV TRANSFORMERS_CACHE=/comfyui/models/cache
ENV HF_HOME=/comfyui/models/cache

RUN mkdir -p /comfyui/models/cache

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

# Structure des modèles HY-Motion (le node cherche dans ckpts/tencent/MODEL_NAME/)
RUN mkdir -p /comfyui/models/HY-Motion/ckpts/tencent
RUN mkdir -p /comfyui/models/HY-Motion/ckpts/openai
RUN mkdir -p /comfyui/models/HY-Motion/ckpts/Qwen

# HY-Motion-1.0 FULL (modèle complet pour qualité maximale)
RUN huggingface-cli download tencent/HY-Motion-1.0 \
    --local-dir /comfyui/models/HY-Motion/ckpts/tencent/HY-Motion-1.0

# CLIP model requis par HY-Motion
RUN huggingface-cli download openai/clip-vit-large-patch14 \
    --local-dir /comfyui/models/HY-Motion/ckpts/openai/clip-vit-large-patch14

# Qwen3-8B LLM FULL (pour génération de mouvement de haute qualité)
RUN huggingface-cli download Qwen/Qwen3-8B \
    --local-dir /comfyui/models/HY-Motion/ckpts/Qwen/Qwen3-8B

# =============================================================================
# Configuration finale
# =============================================================================

ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
ENV TRANSFORMERS_CACHE=/comfyui/models/cache
ENV HF_HOME=/comfyui/models/cache

RUN mkdir -p /comfyui/models/cache

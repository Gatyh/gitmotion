# =============================================================================
# ComfyUI Docker - 3DTexel PBR, Decal & HY-Motion
# =============================================================================
# Workflows disponibles:
#   - workflow_api_pbrify.json          : PBR via PBRify (sans seamless)
#   - workflow_api_pbrify_seamless.json : PBR via PBRify + Seamless
#   - workflow_api_mtb_seamless.json    : PBR via MTB Deep Bump + Seamless
#   - workflow_api_decal.json           : Decal generator (RGB + Alpha séparé)
#   - workflow_api_hymotion.json        : HY-Motion animation (GLB export)
# =============================================================================

FROM runpod/worker-comfyui:5.5.1-base

# -----------------------------------------------------------------------------
# Custom Nodes Installation
# -----------------------------------------------------------------------------

# 1. ComfyUI-MakeSeamlessTexture - Pour la génération de textures seamless
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/SparknightLLC/ComfyUI-MakeSeamlessTexture.git

# 2. comfy_mtb - Pour Deep Bump (Normal/Height generation de haute qualité)
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/melMass/comfy_mtb.git && \
    cd comfy_mtb && \
    pip install -r requirements.txt

# -----------------------------------------------------------------------------
# PBRify Models - Pour upscale et génération PBR
# -----------------------------------------------------------------------------

# 4x Upscaler
RUN wget -O /comfyui/models/upscale_models/4x-PBRify_UpscalerSPAN_Neutral.pth \
    "https://huggingface.co/easygoing0114/AI_upscalers/resolve/main/4x-PBRify_RPLKSRd_V3.pth"

# PBR Map Generators (1x models)
RUN wget -O /comfyui/models/upscale_models/1x-PBRify_Height.pth \
    "https://github.com/Kim2091/PBRify_Remix/raw/main/Models/1x-PBRify_Height.pth"
RUN wget -O /comfyui/models/upscale_models/1x-PBRify_NormalV3.pth \
    "https://github.com/Kim2091/PBRify_Remix/raw/main/Models/1x-PBRify_NormalV3.pth"
RUN wget -O /comfyui/models/upscale_models/1x-PBRify_RoughnessV2.pth \
    "https://github.com/Kim2091/PBRify_Remix/raw/main/Models/1x-PBRify_RoughnessV2.pth"

# -----------------------------------------------------------------------------
# Deep Bump ONNX Model - Requis pour MTB workflows
# Le modèle doit être dans /comfyui/models/deepbump/ ET dans le dossier MTB
# -----------------------------------------------------------------------------
RUN mkdir -p /comfyui/models/deepbump && \
    wget -O /comfyui/models/deepbump/deepbump256.onnx \
    "https://github.com/HugoTini/DeepBump/raw/master/deepbump256.onnx"

# Aussi copier dans le dossier custom_nodes pour MTB (certaines versions le cherchent là)
RUN mkdir -p /comfyui/custom_nodes/comfy_mtb/models && \
    cp /comfyui/models/deepbump/deepbump256.onnx /comfyui/custom_nodes/comfy_mtb/models/

# Installer les dépendances ONNX Runtime pour GPU
RUN pip install onnxruntime-gpu

# =============================================================================
# HY-Motion Animation - FULL QUALITY
# =============================================================================

# 3. ComfyUI-HY-Motion1 custom node
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/jtydhr88/ComfyUI-HY-Motion1.git && \
    cd ComfyUI-HY-Motion1 && \
    pip install -r requirements.txt

# Dépendances supplémentaires pour HY-Motion
RUN pip install accelerate bitsandbytes torchdiffeq

# Structure des modèles HY-Motion
RUN mkdir -p /comfyui/models/HY-Motion/ckpts

# HY-Motion-1.0 FULL (qualité maximale)
RUN huggingface-cli download tencent/HY-Motion-1.0 \
    --local-dir /comfyui/models/HY-Motion/ckpts/HY-Motion-1.0

# CLIP model requis
RUN huggingface-cli download openai/clip-vit-large-patch14 \
    --local-dir /comfyui/models/HY-Motion/ckpts/clip-vit-large-patch14

# Qwen3-8B LLM FULL (qualité maximale)
RUN huggingface-cli download Qwen/Qwen3-8B \
    --local-dir /comfyui/models/HY-Motion/ckpts/Qwen3-8B

# =============================================================================
# Configuration finale
# =============================================================================

ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
ENV TRANSFORMERS_CACHE=/comfyui/models/cache
ENV HF_HOME=/comfyui/models/cache

RUN mkdir -p /comfyui/models/cache

# -----------------------------------------------------------------------------
# Copy workflows (optional - can also be sent via API)
# -----------------------------------------------------------------------------
# COPY workflows/ /comfyui/workflows/
# COPY input/ /comfyui/input/

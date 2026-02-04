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
# Custom handler INLINE - scans /output/ and returns NPZ/FBX files as base64
# =============================================================================
RUN cat > /handler.py << 'HANDLER_EOF'
import runpod
import json
import time
import os
import glob
import base64
import requests
import subprocess

COMFYUI_URL = "http://127.0.0.1:8188"
OUTPUT_DIR = "/comfyui/output"

def start_comfyui():
    """Start ComfyUI server if not running"""
    try:
        requests.get(f"{COMFYUI_URL}/system_stats", timeout=2)
        print("[Handler] ComfyUI already running")
        return True
    except:
        print("[Handler] Starting ComfyUI...")
        subprocess.Popen(["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"],
                        cwd="/comfyui", stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for i in range(60):
            time.sleep(2)
            try:
                requests.get(f"{COMFYUI_URL}/system_stats", timeout=2)
                print(f"[Handler] ComfyUI started after {(i+1)*2}s")
                return True
            except:
                pass
        return False

def submit_workflow(workflow):
    """Submit workflow to ComfyUI"""
    response = requests.post(f"{COMFYUI_URL}/prompt", json={"prompt": workflow})
    if response.status_code == 200:
        return response.json().get("prompt_id")
    return None

def wait_for_completion(prompt_id, timeout=300):
    """Wait for workflow to complete"""
    start = time.time()
    while time.time() - start < timeout:
        try:
            response = requests.get(f"{COMFYUI_URL}/history/{prompt_id}")
            if response.status_code == 200:
                history = response.json()
                if prompt_id in history:
                    return history[prompt_id]
        except:
            pass
        time.sleep(2)
    return None

def scan_output_files():
    """Scan /output/ for NPZ and FBX files created in last 5 minutes"""
    files = {"npz": [], "fbx": []}
    cutoff = time.time() - 300
    
    for ext in ["npz", "fbx"]:
        pattern = os.path.join(OUTPUT_DIR, f"**/*.{ext}")
        for filepath in glob.glob(pattern, recursive=True):
            if os.path.getmtime(filepath) > cutoff:
                with open(filepath, "rb") as f:
                    files[ext].append({
                        "filename": os.path.basename(filepath),
                        "data": base64.b64encode(f.read()).decode("utf-8")
                    })
    return files

def handler(job):
    """Main RunPod handler"""
    job_input = job.get("input", {})
    workflow = job_input.get("workflow")
    
    if not workflow:
        return {"error": "No workflow provided"}
    
    if not start_comfyui():
        return {"error": "Failed to start ComfyUI"}
    
    prompt_id = submit_workflow(workflow)
    if not prompt_id:
        return {"error": "Failed to submit workflow"}
    
    print(f"[Handler] Workflow submitted: {prompt_id}")
    
    result = wait_for_completion(prompt_id, timeout=300)
    if not result:
        return {"error": "Workflow timeout"}
    
    if result.get("status", {}).get("status_str") == "error":
        return {"error": "Workflow failed", "details": result}
    
    # Scan for generated files
    files = scan_output_files()
    print(f"[Handler] Found {len(files['npz'])} NPZ, {len(files['fbx'])} FBX files")
    
    return {
        "status": "success",
        "prompt_id": prompt_id,
        "files": files
    }

if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
HANDLER_EOF

# =============================================================================
# Configuration finale
# =============================================================================

ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
ENV USE_HF_MODELS=1
WORKDIR /comfyui

# Override the default handler to use our custom one
CMD ["python", "-u", "/handler.py"]

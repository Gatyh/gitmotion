"""
Custom RunPod handler for HY-Motion that scans /comfyui/output/ for NPZ/FBX files
and returns them as base64 encoded data in the response.
"""

import os
import sys
import json
import base64
import glob
import time
import subprocess
import runpod

# Add ComfyUI to path
sys.path.insert(0, '/comfyui')

def get_output_files(output_dir="/comfyui/output"):
    """Scan output directory for NPZ and FBX files created in the last 5 minutes."""
    files = {
        "npz": None,
        "fbx": None,
        "npz_filename": None,
        "fbx_filename": None
    }
    
    cutoff_time = time.time() - 300  # 5 minutes ago
    
    # Find most recent NPZ file
    npz_files = glob.glob(os.path.join(output_dir, "*.npz"))
    npz_files = [f for f in npz_files if os.path.getmtime(f) > cutoff_time]
    if npz_files:
        npz_files.sort(key=os.path.getmtime, reverse=True)
        npz_path = npz_files[0]
        with open(npz_path, 'rb') as f:
            files["npz"] = base64.b64encode(f.read()).decode('utf-8')
        files["npz_filename"] = os.path.basename(npz_path)
        print(f"[Handler] Found NPZ: {npz_path}")
    
    # Find most recent FBX file
    fbx_files = glob.glob(os.path.join(output_dir, "*.fbx"))
    fbx_files = [f for f in fbx_files if os.path.getmtime(f) > cutoff_time]
    if fbx_files:
        fbx_files.sort(key=os.path.getmtime, reverse=True)
        fbx_path = fbx_files[0]
        with open(fbx_path, 'rb') as f:
            files["fbx"] = base64.b64encode(f.read()).decode('utf-8')
        files["fbx_filename"] = os.path.basename(fbx_path)
        print(f"[Handler] Found FBX: {fbx_path}")
    
    return files


def handler(job):
    """RunPod handler function."""
    job_input = job.get("input", {})
    
    # Get workflow from input
    workflow = job_input.get("workflow")
    if not workflow:
        return {"error": "No workflow provided"}
    
    print(f"[Handler] Starting HY-Motion job...")
    
    # Clear old files from output directory
    output_dir = "/comfyui/output"
    if os.path.exists(output_dir):
        for f in glob.glob(os.path.join(output_dir, "*.npz")):
            try:
                os.remove(f)
            except:
                pass
        for f in glob.glob(os.path.join(output_dir, "*.fbx")):
            try:
                os.remove(f)
            except:
                pass
    
    # Start ComfyUI server if not running
    comfy_process = None
    try:
        import requests
        requests.get("http://127.0.0.1:8188/", timeout=2)
        print("[Handler] ComfyUI already running")
    except:
        print("[Handler] Starting ComfyUI...")
        comfy_process = subprocess.Popen(
            ["python", "main.py", "--listen", "127.0.0.1", "--port", "8188"],
            cwd="/comfyui",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        # Wait for ComfyUI to start
        for i in range(60):
            try:
                import requests
                requests.get("http://127.0.0.1:8188/", timeout=2)
                print("[Handler] ComfyUI started")
                break
            except:
                time.sleep(1)
    
    # Submit workflow to ComfyUI
    try:
        import requests
        
        # Queue the prompt
        response = requests.post(
            "http://127.0.0.1:8188/prompt",
            json={"prompt": workflow}
        )
        
        if response.status_code != 200:
            return {"error": f"Failed to queue prompt: {response.text}"}
        
        result = response.json()
        prompt_id = result.get("prompt_id")
        print(f"[Handler] Queued prompt: {prompt_id}")
        
        # Wait for completion
        max_wait = 300  # 5 minutes max
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            history_response = requests.get(f"http://127.0.0.1:8188/history/{prompt_id}")
            if history_response.status_code == 200:
                history = history_response.json()
                if prompt_id in history:
                    status = history[prompt_id].get("status", {})
                    if status.get("completed", False):
                        print("[Handler] Workflow completed")
                        break
                    if status.get("status_str") == "error":
                        return {"error": "Workflow execution failed"}
            time.sleep(2)
        
        # Small delay to ensure files are written
        time.sleep(2)
        
        # Scan for output files
        files = get_output_files(output_dir)
        
        if not files["npz"] and not files["fbx"]:
            return {"error": "No output files generated"}
        
        return {
            "status": "success",
            "npz": files["npz"],
            "npz_filename": files["npz_filename"],
            "fbx": files["fbx"],
            "fbx_filename": files["fbx_filename"]
        }
        
    except Exception as e:
        return {"error": str(e)}
    finally:
        if comfy_process:
            comfy_process.terminate()


# Start RunPod serverless handler
runpod.serverless.start({"handler": handler})

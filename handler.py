"""
Custom RunPod handler for HY-Motion that scans /comfyui/output/ for NPZ/FBX files
and returns them as base64 encoded data in the response.
"""

import os
import sys
import requests
import json
import base64
import glob
import time
import subprocess
import hashlib
import hmac
from datetime import datetime
import runpod

# Add ComfyUI to path
sys.path.insert(0, '/comfyui')

# Cloudflare R2 Configuration
R2_ACCOUNT_ID = '6b0f0663f52a9f3e328b989cab046623'
R2_ACCESS_KEY_ID = 'b4faa294328f9af2e1079d311f1ae700'
R2_SECRET_ACCESS_KEY = '0378c26e86d5d59fe8ab78f5c98696b86ece10e4d56b664ea8448b8916be2e14'
R2_BUCKET_NAME = '3d-texel'

def upload_to_r2(file_path, r2_folder="motion"):
    """Upload file to Cloudflare R2 and return the path."""
    try:
        filename = os.path.basename(file_path)
        date_folder = datetime.utcnow().strftime('%Y-%m-%d')
        r2_path = f"{r2_folder}/{date_folder}/{filename}"
        
        with open(file_path, 'rb') as f:
            data = f.read()
        
        region = 'auto'
        service = 's3'
        host = f"{R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
        endpoint = f"https://{host}/{R2_BUCKET_NAME}/{r2_path}"
        
        long_date = datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
        short_date = datetime.utcnow().strftime('%Y%m%d')
        
        content_type = 'application/octet-stream'
        payload_hash = hashlib.sha256(data).hexdigest()
        
        canonical_headers = f"content-type:{content_type}\nhost:{host}\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{long_date}\n"
        signed_headers = "content-type;host;x-amz-content-sha256;x-amz-date"
        
        canonical_request = f"PUT\n/{R2_BUCKET_NAME}/{r2_path}\n\n{canonical_headers}\n{signed_headers}\n{payload_hash}"
        
        credential_scope = f"{short_date}/{region}/{service}/aws4_request"
        string_to_sign = f"AWS4-HMAC-SHA256\n{long_date}\n{credential_scope}\n{hashlib.sha256(canonical_request.encode()).hexdigest()}"
        
        k_secret = ("AWS4" + R2_SECRET_ACCESS_KEY).encode()
        k_date = hmac.new(k_secret, short_date.encode(), hashlib.sha256).digest()
        k_region = hmac.new(k_date, region.encode(), hashlib.sha256).digest()
        k_service = hmac.new(k_region, service.encode(), hashlib.sha256).digest()
        k_signing = hmac.new(k_service, b'aws4_request', hashlib.sha256).digest()
        signature = hmac.new(k_signing, string_to_sign.encode(), hashlib.sha256).hexdigest()
        
        authorization = f"AWS4-HMAC-SHA256 Credential={R2_ACCESS_KEY_ID}/{credential_scope}, SignedHeaders={signed_headers}, Signature={signature}"
        
        headers = {
            'Content-Type': content_type,
            'Host': host,
            'x-amz-content-sha256': payload_hash,
            'x-amz-date': long_date,
            'Authorization': authorization
        }
        
        response = requests.put(endpoint, data=data, headers=headers, timeout=120)
        
        if response.status_code in [200, 201]:
            print(f"[Handler] R2 upload SUCCESS: {r2_path}")
            return r2_path
        else:
            print(f"[Handler] R2 upload FAILED: HTTP {response.status_code}")
            return None
            
    except Exception as e:
        print(f"[Handler] R2 upload error: {e}")
        return None

def get_output_files(output_dir="/comfyui/output"):
    """Scan output directory for NPZ and FBX files, upload to R2."""
    files = {
        "npz_path": None,
        "fbx_path": None,
        "npz_filename": None,
        "fbx_filename": None
    }
    
    cutoff_time = time.time() - 300  # 5 minutes ago
    
    # Find most recent NPZ file
    npz_files = glob.glob(os.path.join(output_dir, "*.npz"))
    npz_files = [f for f in npz_files if os.path.getmtime(f) > cutoff_time]
    if npz_files:
        npz_files.sort(key=os.path.getmtime, reverse=True)
        npz_local = npz_files[0]
        files["npz_filename"] = os.path.basename(npz_local)
        print(f"[Handler] Found NPZ: {npz_local}")
        
        # Upload to R2 instead of base64 (avoids 400 error)
        r2_path = upload_to_r2(npz_local, "motion")
        if r2_path:
            files["npz_path"] = r2_path
    
    # Find most recent FBX file
    fbx_files = glob.glob(os.path.join(output_dir, "*.fbx"))
    fbx_files = [f for f in fbx_files if os.path.getmtime(f) > cutoff_time]
    if fbx_files:
        fbx_files.sort(key=os.path.getmtime, reverse=True)
        fbx_local = fbx_files[0]
        files["fbx_filename"] = os.path.basename(fbx_local)
        print(f"[Handler] Found FBX: {fbx_local}")
        
        # Upload to R2
        r2_path = upload_to_r2(fbx_local, "motion")
        if r2_path:
            files["fbx_path"] = r2_path
    
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
        
        # Scan for output files and upload to R2
        files = get_output_files(output_dir)
        
        if not files["npz_path"] and not files["fbx_path"]:
            return {"error": "No output files generated or R2 upload failed"}
        
        return {
            "status": "success",
            "npz_path": files["npz_path"],
            "npz_filename": files["npz_filename"],
            "fbx_path": files["fbx_path"],
            "fbx_filename": files["fbx_filename"]
        }
        
    except Exception as e:
        return {"error": str(e)}
    finally:
        if comfy_process:
            comfy_process.terminate()


# Start RunPod serverless handler
runpod.serverless.start({"handler": handler})

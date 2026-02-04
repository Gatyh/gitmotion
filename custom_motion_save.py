"""
Custom node to save HY-Motion NPZ and expose it via websocket for RunPod worker
"""
import os
import numpy as np
from datetime import datetime
import uuid

class HYMotionSaveNPZWithOutput:
    @classmethod
    def INPUT_TYPES(s):
        return {
            "required": {
                "motion_data": ("HYMOTION_DATA",),
                "filename_prefix": ("STRING", {"default": "motion_animation"}),
            }
        }
    
    RETURN_TYPES = ()
    FUNCTION = "save_npz"
    OUTPUT_NODE = True
    CATEGORY = "HY-Motion"

    def save_npz(self, motion_data, filename_prefix):
        import folder_paths
        
        try:
            output_dir = folder_paths.get_output_directory()
            
            # Generate unique filename
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S%f")[:-3]
            unique_id = uuid.uuid4().hex[:8]
            filename = f"{filename_prefix}_{timestamp}_{unique_id}_000.npz"
            filepath = os.path.join(output_dir, filename)
            
            # Save motion data as NPZ
            if hasattr(motion_data, 'cpu'):
                data = motion_data.cpu().numpy()
            elif isinstance(motion_data, np.ndarray):
                data = motion_data
            elif isinstance(motion_data, dict):
                np.savez(filepath, **motion_data)
                print(f"[HYMotionSaveNPZWithOutput] Saved: {filepath}")
                return {"ui": {"images": [{"filename": filename, "subfolder": "", "type": "output"}]}}
            else:
                data = np.array(motion_data)
            
            np.savez(filepath, motion=data)
            print(f"[HYMotionSaveNPZWithOutput] Saved: {filepath}")
            
            return {"ui": {"images": [{"filename": filename, "subfolder": "", "type": "output"}]}}
            
        except Exception as e:
            print(f"[HYMotionSaveNPZWithOutput] Error: {e}")
            import traceback
            traceback.print_exc()
            return {"ui": {"images": []}}

NODE_CLASS_MAPPINGS = {
    "HYMotionSaveNPZWithOutput": HYMotionSaveNPZWithOutput
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "HYMotionSaveNPZWithOutput": "HY-Motion Save NPZ (with output)"
}

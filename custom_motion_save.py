"""
Custom node to save HY-Motion NPZ and expose it via websocket for RunPod worker
"""
import os
import folder_paths

class HYMotionSaveNPZWithOutput:
    @classmethod
    def INPUT_TYPES(s):
        return {
            "required": {
                "motion_data": ("MOTION_DATA",),
                "filename_prefix": ("STRING", {"default": "motion_animation"}),
            }
        }
    
    RETURN_TYPES = ()
    FUNCTION = "save_npz"
    OUTPUT_NODE = True
    CATEGORY = "HY-Motion"

    def save_npz(self, motion_data, filename_prefix):
        # Import HY-Motion save function
        try:
            from ComfyUI_HY_Motion1.nodes import HYMotionSaveNPZ
            saver = HYMotionSaveNPZ()
            result = saver.save_npz(motion_data, "", filename_prefix)
            
            # Get the saved file path from result
            if isinstance(result, dict) and 'ui' in result:
                return result
            
            # If no UI output, construct it manually
            output_dir = folder_paths.get_output_directory()
            files = []
            for f in os.listdir(output_dir):
                if f.startswith(filename_prefix) and f.endswith('.npz'):
                    files.append({
                        "filename": f,
                        "subfolder": "",
                        "type": "output"
                    })
            
            return {"ui": {"files": files}}
            
        except Exception as e:
            print(f"[HYMotionSaveNPZWithOutput] Error: {e}")
            return {"ui": {"files": []}}

NODE_CLASS_MAPPINGS = {
    "HYMotionSaveNPZWithOutput": HYMotionSaveNPZWithOutput
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "HYMotionSaveNPZWithOutput": "HY-Motion Save NPZ (with output)"
}

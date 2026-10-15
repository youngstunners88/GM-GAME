set -x
cd /workspace/Hunyuan3D-2.1
ls hy3dshape | head -20
pip install -q transformers diffusers accelerate omegaconf einops safetensors huggingface_hub trimesh pymeshlab rembg onnxruntime opencv-python-headless scikit-image pygltflib xatlas tqdm pyyaml scipy numpy pillow 2>&1 | tail -5
cd hy3dshape && pip install -q --no-deps -e . 2>&1 | tail -3
python3 -c "import hy3dshape; print('hy3dshape import OK')"
echo INSTALL_DONE

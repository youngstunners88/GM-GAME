cd /workspace; exec > /workspace/headjob.log 2>&1; set -x
export TORCH_CUDA_ARCH_LIST="8.9;12.0"
apt-get update -qq; apt-get install -y -qq g++ python3-dev ninja-build libopengl0 libgl1 libglib2.0-0 git wget >/dev/null
test -d Hunyuan3D-2.1 || git clone --depth 1 -q https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1.git
pip install -q 'transformers==4.46.0' 'diffusers==0.30.0' 'huggingface-hub==0.30.2' hf_transfer timm accelerate omegaconf einops safetensors trimesh pymeshlab fast-simplification rembg onnxruntime opencv-python-headless scikit-image pygltflib xatlas pybind11 ninja pytorch-lightning realesrgan basicsr pillow tqdm pyyaml scipy 'git+https://github.com/facebookresearch/segment-anything.git'
pip install -q 'numpy>=2.1,<2.4'
(cd Hunyuan3D-2.1/hy3dshape && pip install -q --no-deps -e .)
(cd Hunyuan3D-2.1/hy3dpaint/custom_rasterizer && pip install -e . --no-build-isolation)
(cd Hunyuan3D-2.1/hy3dpaint/DifferentiableRenderer && bash compile_mesh_painter.sh)
mkdir -p Hunyuan3D-2.1/hy3dpaint/ckpt; wget -q -nc https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth -P Hunyuan3D-2.1/hy3dpaint/ckpt
python3 /workspace/patch.py
sed -i 's/simplify_quadric_decimation(target_count)/simplify_quadric_decimation(face_count=target_count)/' Hunyuan3D-2.1/hy3dpaint/utils/simplify_mesh_utils.py
python3 /workspace/head_gen.py
python3 /workspace/head_decim.py
C=/root/.cache/huggingface/modules/diffusers_modules/local; P=/workspace/Hunyuan3D-2.1/hy3dpaint/hunyuanpaintpbr; mkdir -p $C/unet; cp $P/*.py $C/; cp $P/unet/*.py $C/; cp $P/unet/*.py $C/unet/; touch $C/__init__.py $C/unet/__init__.py
python3 /workspace/head_paint.py
ls -la /workspace | grep -E 'textured|head_'
echo JOB_DONE

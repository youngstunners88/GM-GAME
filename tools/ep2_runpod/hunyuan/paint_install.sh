cd /workspace/Hunyuan3D-2.1
export TORCH_CUDA_ARCH_LIST="12.0"
apt-get install -y -qq g++ ninja-build libglib2.0-0 libgl1 >/dev/null 2>&1
pip install -q pybind11 ninja pytorch-lightning==1.9.5 realesrgan basicsr 'git+https://github.com/facebookresearch/segment-anything.git' 2>&1 | tail -3
pip install -q pytorch-lightning 2>&1 | tail -1
pip install -q 'numpy>=2.1,<2.4' 2>&1 | tail -1
cd hy3dpaint/custom_rasterizer && pip install -e . --no-build-isolation 2>&1 | tail -4
cd ../DifferentiableRenderer && bash compile_mesh_painter.sh 2>&1 | tail -4
cd .. && mkdir -p ckpt && wget -q -nc https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth -P ckpt && ls -la ckpt
echo PAINT_INSTALL_DONE

cd /workspace
exec > /workspace/run_all.log 2>&1
set -x
apt-get install -y -qq python3-dev >/dev/null 2>&1
python3 decim.py
export TORCH_CUDA_ARCH_LIST="12.0"
(cd Hunyuan3D-2.1/hy3dpaint/DifferentiableRenderer && bash compile_mesh_painter.sh)
ls Hunyuan3D-2.1/hy3dpaint/DifferentiableRenderer | head
python3 -c "import custom_rasterizer; print('RASTERIZER_OK')"
python3 paint.py
echo ALL_DONE
# unattended: stop the pod so it stops billing; results stay in /workspace
runpodctl stop pod "$RUNPOD_POD_ID" || runpodctl pod stop "$RUNPOD_POD_ID"

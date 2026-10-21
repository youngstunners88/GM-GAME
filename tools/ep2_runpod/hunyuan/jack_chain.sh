#!/bin/bash
# Jack Hammer: Hunyuan shape -> 60k -> PBR paint (retry on missing modules). Log /workspace/chain.log
cd /workspace; exec > /workspace/chain.log 2>&1; export TORCH_CUDA_ARCH_LIST=8.6
python3 patch_bpy.py; pip install -q xatlas
python3 acc_gen.py /workspace/jhC_700.png jack
for i in 1 2 3 4 5 6 7 8; do
  python3 acc_paint.py jack > paint.log 2>&1
  if grep -q PAINT_DONE paint.log; then echo "PAINT ROUND $i OK"; break; fi
  mod=$(grep -oE "No module named '[^']+'" paint.log | tail -1 | sed "s/No module named '//; s/'//; s/\..*//")
  echo "PAINT ROUND $i missing: $mod"; tail -5 paint.log
  [ -z "$mod" ] && break
  pip install -q "$mod" || break
done
echo CHAIN_DONE

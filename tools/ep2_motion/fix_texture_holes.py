"""Fill unpainted (near-white) holes in a Hunyuan albedo with OpenCV inpainting. Skill ep2-mixamo-pipeline.
  uv run --no-project --with opencv-python-headless --with numpy python tools/ep2_motion/fix_texture_holes.py in.jpg out.jpg"""
import sys
import cv2
import numpy as np
src, dst = sys.argv[1], sys.argv[2]
im = cv2.imread(src)
white = (im.min(axis=2) > 235).astype(np.uint8) * 255                      # pure/near-white = never painted
white = cv2.dilate(white, np.ones((3, 3), np.uint8), iterations=1)
n = int((white > 0).sum())
out = cv2.inpaint(im, white, 5, cv2.INPAINT_TELEA)
cv2.imwrite(dst, out, [cv2.IMWRITE_JPEG_QUALITY, 92])
print("inpainted", n, "px of", im.shape[0] * im.shape[1])

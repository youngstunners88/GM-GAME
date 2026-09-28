# 007 — Founder Meshy share links → game assets (VERIFIED)

`https://www.meshy.ai/s/<code>` redirects to `/3d-models/<slug>-<task uuid>`. Because the founder
generated them with the account the project key belongs to, `GET /openapi/v1/image-to-3d/<uuid>`
returns the task (status, `model_urls.glb`, `thumbnail_url`, prompts). The raw GLBs were 0.5–2.7 M
vertices / 50–173 MB; `meshy remesh create --input-task-id <uuid> --target-polycount 30000..40000`
(5 credits) plus `tools/meshy/shrink_glb.py` got them to 0.7–2.4 MB.

Editing lessons:
- A dead-end wall has THICKNESS: cutting at the wall's centre line left its inner face standing
  (first in-game capture showed rock across the tunnel). Slice face centroids per z band and cut
  the whole band (here z < −0.52, |x| < 0.47).
- `trimesh.split()` on a 40k-face scene OOM'd (thousands of tiny components); k-means on face
  centroids (`scipy.cluster.vq.kmeans2`) separated the six carts cleanly.
- The shell's timber beams sit lower than its rock ceiling — scale Y until the zipline cable clears them.

#!/usr/bin/env python3
"""One-off: generate a treasure chest image bearing the real GM logo, via
Gemini's image model (gemini-2.5-flash-image, publicly "Nano Banana"),
conditioned on the actual logo file so the mark is accurate rather than an
AI approximation of "a GM logo".

Auth: GEMINI_API_KEY env only — never hardcoded (SEC-001).
"""
import base64, json, os, sys, urllib.request

API_KEY = os.environ.get("GEMINI_API_KEY", "")
if not API_KEY:
    sys.exit("GEMINI_API_KEY not set")

LOGO_PATH = sys.argv[1] if len(sys.argv) > 1 else "gm_logo.png"
OUT_PATH = sys.argv[2] if len(sys.argv) > 2 else "chest.png"
PROMPT = (
    "A retro 16-bit pixel-art treasure chest, Wild West Gold Rush style, "
    "carved dark wood with gold metal trim and rivets, sitting closed on "
    "sandy canyon ground. The attached reference image is a real logo "
    "medallion (gold chain ring, 'GM' lettering, pickaxe, mountain peaks, "
    "green glow) — reproduce THIS EXACT LOGO, unaltered, embossed as a "
    "circular gold medallion set into the center of the chest's lid, like "
    "a lock plate. Game asset style: flat lighting, clean pixel-art "
    "shading, no photorealism, transparent background, chest centered, "
    "closed lid, no other text or characters."
)

with open(LOGO_PATH, "rb") as f:
    logo_b64 = base64.b64encode(f.read()).decode()

body = {
    "contents": [{
        "parts": [
            {"text": PROMPT},
            {"inline_data": {"mime_type": "image/png", "data": logo_b64}},
        ]
    }],
    "generationConfig": {"responseModalities": ["IMAGE"]},
}

url = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    "gemini-2.5-flash-image:generateContent"
)
req = urllib.request.Request(
    url, data=json.dumps(body).encode(), method="POST",
    headers={"Content-Type": "application/json", "x-goog-api-key": API_KEY},
)
with urllib.request.urlopen(req, timeout=120) as resp:
    result = json.loads(resp.read())

candidates = result.get("candidates", [])
if not candidates:
    print(json.dumps(result, indent=2)[:2000])
    sys.exit("no candidates returned")

parts = candidates[0].get("content", {}).get("parts", [])
img_data = None
for p in parts:
    if "inlineData" in p:
        img_data = p["inlineData"]["data"]
        break
    if "inline_data" in p:
        img_data = p["inline_data"]["data"]
        break

if not img_data:
    print(json.dumps(result, indent=2)[:2000])
    sys.exit("no image in response")

with open(OUT_PATH, "wb") as f:
    f.write(base64.b64decode(img_data))
print(f"wrote {OUT_PATH}")

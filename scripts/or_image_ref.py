#!/usr/bin/env python3
"""Reference-image generation through OpenRouter (Gemini image models).

Usage: or_image_ref.py <model-id> <prompt-file> <out.png> [--ref a.png --ref b.jpg ...]

Sends the prompt plus optional reference images (data URLs) with
modalities image+text and writes the returned bitmap. Used to draw the
photoreal Diamonds / Gold prop sheets in the same style as the Smoke sheet;
feed the result to scripts/build_prop_atlas.py. Env: OPENROUTER_API_KEY.
"""
import base64, json, mimetypes, os, sys, urllib.request

def main() -> int:
    args = sys.argv[1:]
    refs = []
    while "--ref" in args:
        i = args.index("--ref")
        refs.append(args[i + 1])
        del args[i:i + 2]
    if len(args) != 3:
        print(__doc__)
        return 1
    model, prompt_file, out = args
    key = os.environ.get("OPENROUTER_API_KEY")
    if not key:
        print("ERROR: OPENROUTER_API_KEY not set")
        return 1
    content = [{"type": "text", "text": open(prompt_file, encoding="utf-8").read()}]
    for path in refs:
        mime = mimetypes.guess_type(path)[0] or "image/png"
        b64 = base64.b64encode(open(path, "rb").read()).decode()
        content.append({"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}})
    body = json.dumps({"model": model, "modalities": ["image", "text"],
                       "messages": [{"role": "user", "content": content}]}).encode()
    req = urllib.request.Request("https://openrouter.ai/api/v1/chat/completions", data=body,
                                 headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = json.load(resp)
    msg = data["choices"][0]["message"]
    imgs = msg.get("images") or []
    if not imgs:
        print("ERROR: no image returned:", json.dumps(data)[:800])
        return 4
    url = imgs[0].get("image_url", {}).get("url") or imgs[0].get("url")
    open(out, "wb").write(base64.b64decode(url.split(",", 1)[1]))
    print("OK ->", out)
    return 0

if __name__ == "__main__":
    sys.exit(main())

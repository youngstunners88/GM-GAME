import os, sys, base64, json, urllib.request, urllib.parse
pid, pw = os.environ["PODID"], os.environ["PODPW"]
remote, local = sys.argv[1], sys.argv[2]
req = urllib.request.Request("https://%s-8888.proxy.runpod.net/api/contents/%s?content=1&format=base64&type=file" % (pid, urllib.parse.quote(remote.lstrip("/"))),
  headers={"Authorization":"token "+pw,"User-Agent":"curl/8.5.0"})
r = json.loads(urllib.request.urlopen(req, timeout=600).read())
open(local,"wb").write(base64.b64decode(r["content"])); print("saved", local, os.path.getsize(local))

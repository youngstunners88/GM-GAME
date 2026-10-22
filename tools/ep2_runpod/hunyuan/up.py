import os, sys, base64, json, urllib.request, urllib.parse
pid, pw = os.environ["PODID"], os.environ["PODPW"]
local, remote = sys.argv[1], sys.argv[2]
data = open(local, "rb").read()
body = json.dumps({"type":"file","format":"base64","content":base64.b64encode(data).decode()}).encode()
req = urllib.request.Request("https://%s-8888.proxy.runpod.net/api/contents/%s" % (pid, urllib.parse.quote(remote.lstrip("/"))), data=body, method="PUT",
  headers={"Authorization":"token "+pw,"Content-Type":"application/json","User-Agent":"curl/8.5.0"})
print(urllib.request.urlopen(req, timeout=300).status, len(data))

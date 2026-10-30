import urllib.request,json,pathlib,shutil,sys,hashlib
root=pathlib.Path('/workspace/work/elevator-crossing-1030')
probe=(root/'public-probe.log').read_text()
info,_=json.JSONDecoder().raw_decode(probe[probe.index('{'):])
assert sys.argv[1] in info['build'],info['build']
base=info['gameUrl'].rsplit('/',1)[0]+'/'
out=root/'public-replay'/'game';out.mkdir(parents=True,exist_ok=True)
(out.parent/'views').mkdir(exist_ok=True)
files={}
for name in ['index.html','index.js','index.wasm','index.pck','ep2_extras.pck','web3.js','index.audio.worklet.js','index.icon.png','index.apple-touch-icon.png','index.png']:
    request=urllib.request.Request(base+name+'?proof='+sys.argv[1],headers={'Accept-Encoding':'identity','User-Agent':'GM-GAME-public-release-proof'})
    with urllib.request.urlopen(request,timeout=180) as response,(out/name).open('wb') as stream:
        assert response.headers.get('Content-Encoding','identity') in ['identity','']
        shutil.copyfileobj(response,stream,1024*1024)
    size=(out/name).stat().st_size
    if name.endswith('.pck'):
        with (out/name).open('rb') as stream: assert stream.read(4)==b'GDPC'
        assert size<199229440
    digest=hashlib.file_digest((out/name).open('rb'),'sha512').hexdigest()
    files[name]={'bytes':size,'status':200,'sha512':digest}
    print(name,size,flush=True)
(out.parent/'download-receipt.json').write_text(json.dumps({'game_url':info['gameUrl'],'observed_build':info['build'],'files':files},indent=2)+'\n')

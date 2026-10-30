from pathlib import Path
import sys
p=Path(sys.argv[1]);s=(p/'index.html').read_text();i=s.index('engine.startGame({');a,b=s[:i],s[i:]
b=b.replace('engine.startGame({',"Promise.all([engine.preloadFile('elevator-web.gd','/elevator-web.gd'),engine.preloadFile('ep2_extras.pck','/ep2_extras.pck')]).then(() => engine.startGame({ 'args':['--script','/elevator-web.gd','--','/ep2_extras.pck'],",1).replace('\t\t}).then(() => {','\t\t})).then(() => {',1)
(p/'elevator-web.html').write_text(a+b)
(p/'elevator-web.gd').write_text(Path('/workspace/work/elevator-crossing-1030/elevator-web.gd').read_text())

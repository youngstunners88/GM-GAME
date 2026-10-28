"""Original procedurally authored lake ambience; no third-party samples."""
import numpy as np
from scipy.signal import butter,sosfilt
from scipy.io.wavfile import write
import subprocess
from pathlib import Path
rng=np.random.default_rng(1888);sr=22050;n=sr*24;t=np.arange(n)/sr
noise=rng.normal(size=n)
water=sosfilt(butter(2,[160,2200],btype='bandpass',fs=sr,output='sos'),noise)*(.10+.035*np.sin(2*np.pi*t*.31)+.025*np.sin(2*np.pi*t*.53))
crickets=np.zeros(n);frogs=np.zeros(n)
for start in np.arange(.4,24,.73):
 for pulse in range(4):
  a=int((start+pulse*.065)*sr);length=min(int(.045*sr),n-a)
  if length<=0:continue
  x=np.arange(length)/sr
  crickets[a:a+length]+=.13*np.sin(np.pi*np.arange(length)/length)**2*np.sin(2*np.pi*(3900*x+25*x*x))
for start in [1.2,4.9,8.3,13.8,18.1,22]:
 a=int(start*sr);length=min(int(.65*sr),n-a);x=np.arange(length)/sr
 phase=2*np.pi*(145*x-40*x*x)
 frogs[a:a+length]+=.22*np.sin(np.pi*np.arange(length)/length)**2*(np.sin(phase)+.4*np.sin(phase*2))*(.6+.4*np.sin(2*np.pi*x*19))
root=Path('src/episode2/extras/audio/lake');root.mkdir(parents=True,exist_ok=True)
for name,data in [('water',water),('insects',crickets),('frogs',frogs)]:
 wav=Path('/workspace/work/lake-life')/(name+'.wav');write(wav,sr,np.int16(np.clip(data,-1,1)*32767))
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','3',str(root/(name+'.ogg'))],check=True)

"""Original miniature racing compositions; deterministic synthesis, no sampled recordings."""
from pathlib import Path
import numpy as np
import wave
RATE=22050
OUT=Path(__file__).parent
rng=np.random.default_rng(260913)
def frequency(m): return 440*2**((m-69)/12)
def build(theme,bpm,roots,motif):
 beat=60/bpm; duration=64*beat; n=round(duration*RATE); mix=np.zeros((n,2),np.float64)
 def put(note,start,length,gain,kind='pluck',pan=0):
  count=round(length*RATE); t=np.arange(count)/RATE
  if kind=='kick':
   phase=2*np.pi*(45*t+18*(1-np.exp(-t*30))); v=np.sin(phase)*np.exp(-t*15)
  elif kind=='snare': v=(rng.standard_normal(count)*.7+np.sin(2*np.pi*180*t)*.3)*np.exp(-t*28)
  elif kind=='hat':
   noise=rng.standard_normal(count); v=np.diff(noise,prepend=0)*np.exp(-t*90)*.4
  else:
   f=frequency(note); phase=2*np.pi*f*t
   if kind=='bass': v=(np.sin(phase)+.22*np.sin(phase*2))*np.exp(-t*3.7)
   elif kind=='pad': v=(np.sin(phase)+.18*np.sin(phase*2))*np.minimum(t/.08,1)*np.minimum((length-t)/.15,1)*.55
   elif kind=='bell': v=(np.sin(phase)+.22*np.sin(phase*3))*np.exp(-t*5)
   else: v=(np.sin(phase)+.25*np.sin(phase*2)+.08*np.sin(phase*4))*np.exp(-t*7)
  v*=np.minimum(t/.005,1)*np.minimum((length-t)/.015,1)*gain
  ix=(round(start*RATE)+np.arange(count))%n
  np.add.at(mix[:,0],ix,v*np.sqrt((1-pan)/2));np.add.at(mix[:,1],ix,v*np.sqrt((1+pan)/2))
 for bar in range(16):
  root=roots[(bar//2)%len(roots)]
  for third in [0,4 if theme!='castle' else 3,7]: put(root+third+12,bar*4*beat,4.1*beat,.037,'pad',third/10-.35)
  for b in range(4):
   at=(bar*4+b)*beat
   put(root-12+(7 if b==3 else 0),at,beat*.85,.18,'bass')
   if theme!='sky' or b%2==0: put(0,at,.21,.3,'kick')
   if b%2==1: put(0,at,.18,.12,'snare',.1)
   for half in range(2): put(0,at+half*beat/2,.065,.055,'hat',-.3 if half else .3)
  phrase=motif if bar%4<2 else list(reversed(motif))
  for j,degree in enumerate(phrase):
   if degree is None or (bar in [7,15] and j>5): continue
   # Four phrases vary register, rhythm and instrumental response.
   octave=12 if 8<=bar<12 else 0
   start=(bar*4+j*.5)*beat
   put(root+12+degree+octave,start,beat*(.7 if j%2 else 1.0),.145,'bell' if theme=='sky' else 'pluck',.2)
   if bar>=4 and j%2==1: put(root+24+degree,start+beat*.22,beat*.55,.032,'bell',-.5)
  if bar%4==3:
   for j in range(4): put(0,(bar*4+3+j/4)*beat,.1,.07,'snare',j/6-.3)
 mix=np.tanh(mix*1.2)
 mix*=.88/max(.88,float(np.max(np.abs(mix))))
 # Fade only the last/first 2ms to remove a numerical seam, inaudible at the downbeat.
 fade=int(.002*RATE);mix[:fade]*=np.linspace(0,1,fade)[:,None];mix[-fade:]*=np.linspace(1,0,fade)[:,None]
 pcm=np.asarray(mix*32767,dtype='<i2')
 with wave.open(str(OUT/(theme+'.wav')),'wb') as w: w.setnchannels(2);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(pcm.tobytes())
 print(theme,round(duration,2),'seconds, peak',round(float(abs(mix).max()),3))
build('desk',130,[60,65,57,67],[0,4,7,None,9,7,4,2])
build('castle',122,[62,58,65,60],[0,7,3,7,10,7,3,None])
build('sky',116,[65,60,62,58],[7,12,9,None,4,7,2,4])

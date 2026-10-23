#!/usr/bin/env python3
"""Numerical tests of the shipping C DSP; no audio device or capture permission."""
import ctypes as C
import math, pathlib, subprocess, tempfile, random
root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='m8-dsp-test-') as temp:
    lib=pathlib.Path(temp)/'dsp.dylib'
    subprocess.run(['xcrun','clang','-O2','-std=c11','-shared','-o',str(lib),str(root/'Sound/DSP/M8DSP.c')],check=True)
    d=C.CDLL(str(lib))
    d.m8_create.argtypes=[C.c_double,C.POINTER(C.c_double)]; d.m8_create.restype=C.c_void_p
    d.m8_destroy.argtypes=[C.c_void_p]
    d.m8_process.argtypes=[C.c_void_p,C.POINTER(C.c_float),C.c_int]
    d.m8_headroom.argtypes=[C.c_void_p]; d.m8_headroom.restype=C.c_double
    d.m8_frames.argtypes=[C.c_void_p]; d.m8_frames.restype=C.c_uint64
    presets={'warm':[0,2.5,1,0,0,-.5,-2,-1.5], 'bass':[1,4,1.5,0,0,-1,-2.5,-1.5], 'voice':[-2,0,0,0,1,1.5,-1,-1], 'flat':[0]*8}
    count=0
    def check(condition,label):
        global count
        assert condition,label
        count+=1; print('PASS',label)
    def create(rate,gains): return d.m8_create(rate,(C.c_double*8)(*gains))
    def render(rate,gains,samples):
        handle=create(rate,gains); assert handle
        buf=(C.c_float*len(samples))(*samples)
        # Irregular blocks exercise delay/deque continuity.
        for begin in range(0,len(samples)//2,137):
            n=min(137,len(samples)//2-begin)
            d.m8_process(handle,C.cast(C.byref(buf,begin*2*4),C.POINTER(C.c_float)),n)
        result=list(buf); frames=d.m8_frames(handle); headroom=d.m8_headroom(handle)
        d.m8_destroy(handle)
        assert frames==len(samples)//2
        return result,headroom
    def rms(xs): return math.sqrt(sum(x*x for x in xs)/len(xs))
    def level(rate,gains,freq):
        samples=[v for i in range(rate//4) for v in [0.03*math.sin(2*math.pi*freq*i/rate)]*2]
        out,_=render(rate,gains,samples)
        return 20*math.log10(rms(out[rate//4:])/ (0.03/math.sqrt(2)))
    for rate in (32000,44100,48000,96000,192000):
        for name,gains in presets.items():
            bass=level(rate,gains,125)-level(rate,gains,1000)
            high=level(rate,gains,4000)-level(rate,gains,1000)
            if name=='bass': check(bass>3 and high<-1.5,f'{rate} Hz bass boost and harshness reduction')
            if name=='warm': check(bass>1.5 and high<-1,f'{rate} Hz warmth response')
            out,h=render(rate,gains,[0.0]*(rate//4*2))
            check(all(x==0 for x in out),f'{rate} Hz {name}: silence remains silent')
    rng=random.Random(20261022)
    for gains in [presets['bass'],[6]*8,[-6]*8,[6,-6]*4]:
        samples=[rng.uniform(-4,4) for _ in range(48000)]
        samples[100]=float('nan'); samples[101]=float('inf')
        out,h=render(48000,gains,samples)
        check(all(math.isfinite(x) and abs(x)<=.980001 for x in out),'overload and nonfinite input remain bounded')
        check(h>=1.5,'automatic headroom enabled')
    impulse=[0.0]*96000; impulse[0]=1
    out,_=render(48000,presets['bass'],impulse)
    check(all(x==0 for x in out[1::2]),'stereo channels isolated')
    check(max(abs(x) for x in out[-1000:])<1e-10,'impulse decays without unstable ringing')
    check(all(x==0 for x in out[:480]),'5 ms lookahead at 48 kHz')
    check(not create(0,[0]*8) and not create(48000,[7]*8) and not create(48000,[float('nan')]*8),'invalid configurations rejected')
    # A huge impulse should engage the linked limiter while keeping L/R ratio.
    signal=[0.0]*9600
    for i in range(1000,2000): signal[2*i]=8; signal[2*i+1]=4
    out,_=render(48000,[0]*8,signal)
    check(max(abs(out[i]-2*out[i+1]) for i in range(0,len(out),2))<1e-6,'linked stereo limiter preserves image')
    print(f'{count} PASS')

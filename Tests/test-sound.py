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
    # Channel/dynamics controls are opt-in; neutral settings retain EQ behavior.
    d.m8_create_with_options.argtypes=[C.c_double,C.POINTER(C.c_double),C.c_double,C.c_int,C.c_double,C.c_double,C.c_int]
    d.m8_create_with_options.restype=C.c_void_p
    def enhanced(samples,balance=0,mono=0,left=0,right=0,night=0,rate=48000):
        handle=d.m8_create_with_options(rate,(C.c_double*8)(*([0]*8)),balance,mono,left,right,night)
        assert handle
        buf=(C.c_float*len(samples))(*samples)
        for begin in range(0,len(samples)//2,137):
            n=min(137,len(samples)//2-begin)
            d.m8_process(handle,C.cast(C.byref(buf,begin*2*4),C.POINTER(C.c_float)),n)
        result=list(buf); d.m8_destroy(handle)
        return result
    tone=[v for i in range(24000) for v in [0.03*math.sin(2*math.pi*1000*i/48000),0]]
    neutral,_=render(48000,[0]*8,tone)
    check(enhanced(tone)==neutral,'neutral stereo options preserve original processing')
    mono=enhanced(tone,mono=1)
    check(max(abs(mono[i]-mono[i+1]) for i in range(0,len(mono),2))<1e-7,'mono maps left-only input equally to both channels')
    check(abs(rms(mono[2000::2])/rms(neutral[2000::2])-0.5)<1e-6,'mono averages without a gain boost')
    anti=[v for i in range(12000) for v in [0.2*math.sin(i*0.13),-0.2*math.sin(i*0.13)]]
    check(all(x==0 for x in enhanced(anti,mono=1)),'opposite-phase mono cancels without added signal')
    balanced=enhanced(tone,balance=1)
    check(all(x==0 for x in balanced),'full-right balance silences left-only material')
    rightTone=[v for i in range(12000) for v in [0,0.1*math.sin(i*0.13)]]
    check(all(x==0 for x in enhanced(rightTone,balance=-1)),'full-left balance silences right-only material')
    trimmed=enhanced(tone,left=-6)
    check(abs(rms(trimmed[2000::2])/rms(neutral[2000::2])-10**(-6/20))<1e-6,'left channel trim is exact attenuation')
    stereoTone=[v for i in range(24000) for v in [0.04*math.sin(i*0.13)]*2]
    rt=enhanced(stereoTone,right=-12)
    check(abs(rms(rt[2000::2])/rms(rt[2001::2])-10**(12/20))<1e-5,'right trim does not affect left channel')
    check(enhanced(tone,night=1)==neutral,'night mode leaves quiet material unchanged')
    loud=[v for i in range(48000) for v in [0.8*math.sin(i*0.13),0.4*math.sin(i*0.13)]]
    plain=enhanced(loud); night=enhanced(loud,night=1)
    check(rms(night[48000:])<rms(plain[48000:])*0.65,'night mode reduces sustained loud peaks')
    check(max(abs(night[i]-2*night[i+1]) for i in range(0,len(night),2))<1e-6,'night compression is stereo-linked')
    for rate in (32000,44100,48000,96000,192000):
        hostile=[float('nan'),float('inf')]+[rng.uniform(-10,10) for _ in range(12000)]
        output=enhanced(hostile,balance=0.2,mono=1,left=-1,right=-2,night=1,rate=rate)
        check(all(math.isfinite(v) and abs(v)<=.980001 for v in output),f'{rate} Hz enhanced overload remains finite and bounded')
    for options in [(1.1,0,0,0,0),(0,2,0,0,0),(0,0,1,0,0),(0,0,0,-13,0),(0,0,0,0,2),(float('nan'),0,0,0,0)]:
        check(not d.m8_create_with_options(48000,(C.c_double*8)(*([0]*8)),*options),'invalid stereo/dynamics configuration rejected')
    print(f'{count} PASS')

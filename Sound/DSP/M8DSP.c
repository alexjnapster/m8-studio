// RBJ peaking / high-pass coefficients: W3C Audio EQ Cookbook.
// No allocation, locks, logging or Objective-C in the render callback.
#include "M8DSP.h"
#include <stdlib.h>
#include <math.h>
#include <complex.h>
#include <stdatomic.h>
#define BANDS 9
#define DELAY 2048
struct Filter { double b0,b1,b2,a1,a2,z1[2],z2[2]; };
struct M8DSP {
    struct Filter f[BANDS]; double attenuation, headroom, release, gain;
    float delay[DELAY][2]; int lookahead; uint64_t cursor;
    double maxima[DELAY]; uint64_t positions[DELAY]; int front, back;
    _Atomic(uint64_t) frames; _Atomic(float) peak, reduction;
};
static struct Filter coefficients(double rate,double frequency,double gain,int highpass) {
    double w=2*M_PI*frequency/rate,c=cos(w),a=sin(w)/(2*(highpass ? 0.70710678118 : 1.0));
    double A=pow(10,gain/40),a0=1+a/A;
    struct Filter f={0};
    if(highpass) { a0=1+a; f.b0=(1+c)/2/a0; f.b1=-(1+c)/a0; f.b2=f.b0; f.a1=-2*c/a0; f.a2=(1-a)/a0; }
    else { f.b0=(1+a*A)/a0; f.b1=-2*c/a0; f.b2=(1-a*A)/a0; f.a1=-2*c/a0; f.a2=(1-a/A)/a0; }
    return f;
}
M8DSP *m8_create(double rate,const double gains[8]) {
    if(!isfinite(rate)||rate<32000||rate>192000||!gains) return NULL;
    for(int i=0;i<8;i++) if(!isfinite(gains[i])||fabs(gains[i])>6) return NULL;
    M8DSP *d=calloc(1,sizeof(*d)); if(!d) return NULL;
    const double frequencies[8]={63,125,250,500,1000,2000,4000,8000};
    d->f[0]=coefficients(rate,50,0,1);
    for(int i=0;i<8;i++) d->f[i+1]=coefficients(rate,frequencies[i],gains[i],0);
    double maximum=0;
    for(int n=0;n<4096;n++) {
        double frequency=20*pow((rate/2-1)/20,(double)n/4095);
        double complex z=cexp(-I*2*M_PI*frequency/rate),response=1;
        for(int i=0;i<BANDS;i++) { struct Filter *f=&d->f[i]; response*=(f->b0+f->b1*z+f->b2*z*z)/(1+f->a1*z+f->a2*z*z); }
        double db=20*log10(fmax(1e-15,cabs(response))); if(db>maximum) maximum=db;
    }
    d->headroom=maximum+1.5; d->attenuation=pow(10,-d->headroom/20);
    d->gain=1; d->release=exp(-1/(rate*0.12)); d->lookahead=(int)(rate*0.005);
    return d;
}
void m8_destroy(M8DSP *d) { free(d); }
double m8_headroom(M8DSP *d) { return d ? d->headroom : 0; }
uint64_t m8_frames(M8DSP *d) { return d ? atomic_load_explicit(&d->frames,memory_order_relaxed) : 0; }
float m8_peak(M8DSP *d) { return d ? atomic_exchange_explicit(&d->peak,0,memory_order_relaxed) : 0; }
float m8_reduction(M8DSP *d) { return d ? atomic_load_explicit(&d->reduction,memory_order_relaxed) : 0; }
void m8_process(M8DSP *d,float *samples,int frames) {
    if(!d||!samples||frames<=0) return;
    double blockPeak=0,blockReduction=0;
    for(int frame=0;frame<frames;frame++) {
        double value[2];
        for(int ch=0;ch<2;ch++) {
            double x=samples[frame*2+ch]; if(!isfinite(x)) x=0;
            for(int i=0;i<BANDS;i++) {
                struct Filter *f=&d->f[i]; double y=f->b0*x+f->z1[ch];
                f->z1[ch]=f->b1*x-f->a1*y+f->z2[ch]; f->z2[ch]=f->b2*x-f->a2*y; x=y;
            }
            value[ch]=x*d->attenuation;
        }
        double peak=fmax(fabs(value[0]),fabs(value[1]));
        uint64_t cursor=d->cursor++;
        while(d->front!=d->back && d->positions[d->front]+d->lookahead<cursor) d->front=(d->front+1)%DELAY;
        while(d->front!=d->back) { int last=(d->back+DELAY-1)%DELAY; if(d->maxima[last]>peak) break; d->back=last; }
        d->maxima[d->back]=peak; d->positions[d->back]=cursor; d->back=(d->back+1)%DELAY;
        double target=fmin(1,0.98/fmax(1e-20,d->maxima[d->front]));
        d->gain=target<d->gain ? target : fmin(target,1-(1-d->gain)*d->release);
        int write=(int)(cursor%DELAY),read=(int)((cursor+DELAY-d->lookahead)%DELAY);
        for(int ch=0;ch<2;ch++) {
            d->delay[write][ch]=(float)value[ch];
            double out=cursor>=(uint64_t)d->lookahead ? d->delay[read][ch]*d->gain : 0;
            out=fmax(-0.98,fmin(0.98,out)); samples[frame*2+ch]=(float)out;
            blockPeak=fmax(blockPeak,fabs(out));
        }
        blockReduction=fmax(blockReduction,1-d->gain);
    }
    atomic_fetch_add_explicit(&d->frames,(uint64_t)frames,memory_order_relaxed);
    float previous=atomic_load_explicit(&d->peak,memory_order_relaxed);
    while(previous<blockPeak && !atomic_compare_exchange_weak_explicit(&d->peak,&previous,(float)blockPeak,memory_order_relaxed,memory_order_relaxed)) {}
    atomic_store_explicit(&d->reduction,(float)blockReduction,memory_order_relaxed);
}
struct M8Gate { _Atomic(int) enabled; };
M8Gate *m8_gate_create(void) { return calloc(1,sizeof(M8Gate)); }
void m8_gate_destroy(M8Gate *gate) { free(gate); }
void m8_gate_set(M8Gate *gate,int enabled) { atomic_store_explicit(&gate->enabled,enabled,memory_order_release); }
int m8_gate_get(M8Gate *gate) { return atomic_load_explicit(&gate->enabled,memory_order_acquire); }

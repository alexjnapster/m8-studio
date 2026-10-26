#pragma once
#include <stdint.h>
typedef struct M8DSP M8DSP;
M8DSP *m8_create(double sampleRate, const double gains[8]);
M8DSP *m8_create_with_options(double sampleRate, const double gains[8], double balance, int mono, double leftTrim, double rightTrim, int nightMode);
void m8_destroy(M8DSP *dsp);
void m8_process(M8DSP *dsp, float *interleaved, int frames);
double m8_headroom(M8DSP *dsp);
uint64_t m8_frames(M8DSP *dsp);
float m8_peak(M8DSP *dsp);
float m8_reduction(M8DSP *dsp);
typedef struct M8Gate M8Gate;
M8Gate *m8_gate_create(void);
void m8_gate_destroy(M8Gate *gate);
void m8_gate_set(M8Gate *gate, int enabled);
int m8_gate_get(M8Gate *gate);

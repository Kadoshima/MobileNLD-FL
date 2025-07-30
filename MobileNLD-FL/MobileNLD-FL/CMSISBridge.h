//
//  CMSISBridge.h
//  MobileNLD-FL
//
//  Bridge header for CMSIS-DSP baseline comparison
//  This demonstrates generic DSP library limitations vs our NLD-specific optimization
//

#ifndef CMSISBridge_h
#define CMSISBridge_h

#include <stdint.h>
#include <stddef.h>

// CMSIS-DSP style Q15 operations (baseline for comparison)
typedef struct {
    int16_t* data;
    size_t length;
} q15_vector_t;

typedef struct {
    double processing_time_ms;
    double simd_utilization_percent;
    uint64_t total_instructions;
    uint64_t simd_instructions;
    double memory_bandwidth_gb_s;
} performance_metrics_t;

// CMSIS-DSP baseline implementations
performance_metrics_t cmsis_compute_lyapunov_q15(const q15_vector_t* signal, 
                                                 int embedding_dim, 
                                                 int time_delay,
                                                 int16_t* result);

performance_metrics_t cmsis_compute_dfa_q15(const q15_vector_t* signal,
                                           int min_box_size,
                                           int max_box_size,
                                           int16_t* alpha);

// Our optimized NLD-specific implementations  
performance_metrics_t nld_compute_lyapunov_q15(const q15_vector_t* signal,
                                               int embedding_dim,
                                               int time_delay,
                                               int16_t* result);

performance_metrics_t nld_compute_dfa_q15(const q15_vector_t* signal,
                                         int min_box_size,
                                         int max_box_size,
                                         int16_t* alpha);

// Performance measurement utilities
void reset_performance_counters(void);
performance_metrics_t get_performance_metrics(void);

// SIMD utilization measurement
double measure_simd_utilization(void);

#endif /* CMSISBridge_h */
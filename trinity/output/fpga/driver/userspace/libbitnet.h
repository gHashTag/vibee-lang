/*
 * VIBEE BitNet Userspace Library Header
 *
 * Священная Формула: V = n × 3^k × π^m × φ^p × e^q
 * Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
 *
 * Copyright (c) 2024 VIBEE Project
 * SPDX-License-Identifier: MIT
 */

#ifndef _LIBBITNET_H_
#define _LIBBITNET_H_

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ═══════════════════════════════════════════════════════════════════════════
 * Types
 * ═══════════════════════════════════════════════════════════════════════════ */

/* Opaque context handle */
typedef struct bitnet_ctx bitnet_ctx_t;

/* State enumeration */
typedef enum {
    BITNET_STATE_IDLE = 0,
    BITNET_STATE_LOADING_WEIGHTS,
    BITNET_STATE_RUNNING,
    BITNET_STATE_DMA_TRANSFER,
    BITNET_STATE_ERROR,
} bitnet_state_t;

/* Status structure */
typedef struct {
    bitnet_state_t state;
    uint32_t current_layer;
    uint32_t tokens_processed;
    uint32_t error_code;
} bitnet_status_t;

/* Performance metrics */
typedef struct {
    uint64_t total_cycles;
    uint64_t dma_cycles;
    uint64_t compute_cycles;
    uint32_t tokens_per_second;
    uint32_t inference_count;
} bitnet_perf_t;

/* Model info */
typedef struct {
    uint32_t num_layers;
    uint32_t hidden_size;
    uint32_t vocab_size;
    uint32_t max_seq_len;
    uint64_t weight_size;
} bitnet_model_info_t;

/* Error codes */
#define BITNET_SUCCESS          0
#define BITNET_ERR_OPEN         -1
#define BITNET_ERR_MMAP         -2
#define BITNET_ERR_IOCTL        -3
#define BITNET_ERR_TIMEOUT      -4
#define BITNET_ERR_BUSY         -5
#define BITNET_ERR_INVALID      -6
#define BITNET_ERR_NO_MEMORY    -7
#define BITNET_ERR_HW_ERROR     -8
#define BITNET_ERR_FILE         -9

/* ═══════════════════════════════════════════════════════════════════════════
 * Initialization / Cleanup
 * ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Initialize BitNet context
 * 
 * @param device Device path (e.g., "/dev/bitnet0") or NULL for default
 * @return Context handle or NULL on error
 */
bitnet_ctx_t *bitnet_init(const char *device);

/**
 * Destroy BitNet context
 * 
 * @param ctx Context handle
 */
void bitnet_destroy(bitnet_ctx_t *ctx);

/**
 * Reset hardware
 * 
 * @param ctx Context handle
 * @return 0 on success, negative error code on failure
 */
int bitnet_reset(bitnet_ctx_t *ctx);

/* ═══════════════════════════════════════════════════════════════════════════
 * Weight Management
 * ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Load weights from file
 * 
 * @param ctx Context handle
 * @param model_path Path to model weights file
 * @return 0 on success, negative error code on failure
 */
int bitnet_load_weights(bitnet_ctx_t *ctx, const char *model_path);

/**
 * Load weights for a specific layer
 * 
 * @param ctx Context handle
 * @param layer_id Layer index (0-based)
 * @param weights Pointer to weight data
 * @param size Size of weight data in bytes
 * @return 0 on success, negative error code on failure
 */
int bitnet_load_layer_weights(bitnet_ctx_t *ctx, int layer_id,
                              const void *weights, size_t size);

/**
 * Get model information
 * 
 * @param ctx Context handle
 * @param info Pointer to model info structure
 * @return 0 on success, negative error code on failure
 */
int bitnet_get_model_info(bitnet_ctx_t *ctx, bitnet_model_info_t *info);

/* ═══════════════════════════════════════════════════════════════════════════
 * Inference
 * ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Run synchronous inference
 * 
 * @param ctx Context handle
 * @param input_tokens Input token IDs
 * @param num_tokens Number of input tokens
 * @param output_tokens Output buffer for generated tokens
 * @param max_output Maximum number of output tokens
 * @return Number of generated tokens, or negative error code
 */
int bitnet_inference(bitnet_ctx_t *ctx,
                     const int32_t *input_tokens, int num_tokens,
                     int32_t *output_tokens, int max_output);

/**
 * Start asynchronous inference
 * 
 * @param ctx Context handle
 * @param input_tokens Input token IDs
 * @param num_tokens Number of input tokens
 * @return 0 on success, negative error code on failure
 */
int bitnet_inference_async(bitnet_ctx_t *ctx,
                           const int32_t *input_tokens, int num_tokens);

/**
 * Wait for inference completion
 * 
 * @param ctx Context handle
 * @param timeout_ms Timeout in milliseconds (-1 for infinite)
 * @return 0 on success, negative error code on failure/timeout
 */
int bitnet_wait(bitnet_ctx_t *ctx, int timeout_ms);

/**
 * Get inference output
 * 
 * @param ctx Context handle
 * @param output_tokens Output buffer for generated tokens
 * @param max_output Maximum number of output tokens
 * @return Number of generated tokens, or negative error code
 */
int bitnet_get_output(bitnet_ctx_t *ctx,
                      int32_t *output_tokens, int max_output);

/**
 * Abort running inference
 * 
 * @param ctx Context handle
 * @return 0 on success, negative error code on failure
 */
int bitnet_abort(bitnet_ctx_t *ctx);

/* ═══════════════════════════════════════════════════════════════════════════
 * Status / Performance
 * ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Get current status
 * 
 * @param ctx Context handle
 * @param status Pointer to status structure
 * @return 0 on success, negative error code on failure
 */
int bitnet_get_status(bitnet_ctx_t *ctx, bitnet_status_t *status);

/**
 * Get performance metrics
 * 
 * @param ctx Context handle
 * @param perf Pointer to performance structure
 * @return 0 on success, negative error code on failure
 */
int bitnet_get_perf(bitnet_ctx_t *ctx, bitnet_perf_t *perf);

/**
 * Check if accelerator is busy
 * 
 * @param ctx Context handle
 * @return 1 if busy, 0 if idle, negative on error
 */
int bitnet_is_busy(bitnet_ctx_t *ctx);

/* ═══════════════════════════════════════════════════════════════════════════
 * Direct Buffer Access (Advanced)
 * ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Get pointer to input buffer (zero-copy)
 * 
 * @param ctx Context handle
 * @param size Pointer to receive buffer size
 * @return Pointer to input buffer, or NULL on error
 */
void *bitnet_get_input_buffer(bitnet_ctx_t *ctx, size_t *size);

/**
 * Get pointer to output buffer (zero-copy)
 * 
 * @param ctx Context handle
 * @param size Pointer to receive buffer size
 * @return Pointer to output buffer, or NULL on error
 */
void *bitnet_get_output_buffer(bitnet_ctx_t *ctx, size_t *size);

/**
 * Get pointer to weight buffer (zero-copy)
 * 
 * @param ctx Context handle
 * @param size Pointer to receive buffer size
 * @return Pointer to weight buffer, or NULL on error
 */
void *bitnet_get_weight_buffer(bitnet_ctx_t *ctx, size_t *size);

/* ═══════════════════════════════════════════════════════════════════════════
 * Utility Functions
 * ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Get error string
 * 
 * @param error_code Error code
 * @return Error description string
 */
const char *bitnet_strerror(int error_code);

/**
 * Get library version
 * 
 * @return Version string
 */
const char *bitnet_version(void);

/**
 * Get hardware version
 * 
 * @param ctx Context handle
 * @param major Pointer to receive major version
 * @param minor Pointer to receive minor version
 * @param patch Pointer to receive patch version
 * @return 0 on success, negative error code on failure
 */
int bitnet_hw_version(bitnet_ctx_t *ctx, int *major, int *minor, int *patch);

#ifdef __cplusplus
}
#endif

#endif /* _LIBBITNET_H_ */

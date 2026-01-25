/*
 * VIBEE BitNet Userspace Library Implementation
 *
 * Священная Формула: V = n × 3^k × π^m × φ^p × e^q
 * Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
 *
 * Copyright (c) 2024 VIBEE Project
 * SPDX-License-Identifier: MIT
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <poll.h>

#include "libbitnet.h"

/* IOCTL definitions from kernel header */
#include <linux/ioctl.h>

#define BITNET_IOC_MAGIC    'B'

struct bitnet_inference_req {
    uint64_t input_offset;
    uint64_t output_offset;
    uint32_t input_size;
    uint32_t output_size;
    uint32_t num_tokens;
    uint32_t flags;
};

struct bitnet_weight_req {
    uint64_t weight_offset;
    uint32_t layer_id;
    uint32_t weight_size;
};

struct bitnet_status {
    uint32_t state;
    uint32_t current_layer;
    uint32_t tokens_processed;
    uint32_t error_code;
};

struct bitnet_perf {
    uint64_t total_cycles;
    uint64_t dma_cycles;
    uint64_t compute_cycles;
    uint32_t tokens_per_second;
    uint32_t reserved;
};

#define BITNET_IOC_START_INFERENCE  _IOW(BITNET_IOC_MAGIC, 1, struct bitnet_inference_req)
#define BITNET_IOC_LOAD_WEIGHTS     _IOW(BITNET_IOC_MAGIC, 2, struct bitnet_weight_req)
#define BITNET_IOC_GET_STATUS       _IOR(BITNET_IOC_MAGIC, 3, struct bitnet_status)
#define BITNET_IOC_WAIT_COMPLETE    _IO(BITNET_IOC_MAGIC, 4)
#define BITNET_IOC_ABORT            _IO(BITNET_IOC_MAGIC, 5)
#define BITNET_IOC_GET_PERF         _IOR(BITNET_IOC_MAGIC, 6, struct bitnet_perf)
#define BITNET_IOC_RESET            _IO(BITNET_IOC_MAGIC, 7)

/* Buffer sizes */
#define MMAP_BUFFER_SIZE        (256 * 1024 * 1024)
#define INPUT_BUFFER_SIZE       (64 * 1024 * 1024)
#define OUTPUT_BUFFER_SIZE      (64 * 1024 * 1024)
#define WEIGHT_BUFFER_SIZE      (128 * 1024 * 1024)

#define LIBBITNET_VERSION "1.0.0"
#define DEFAULT_DEVICE "/dev/bitnet0"

/* ═══════════════════════════════════════════════════════════════════════════
 * Context structure
 * ═══════════════════════════════════════════════════════════════════════════ */

struct bitnet_ctx {
    int fd;
    void *mmap_buf;
    size_t mmap_size;
    
    /* Buffer offsets */
    size_t input_offset;
    size_t output_offset;
    size_t weight_offset;
    
    /* Buffer sizes */
    size_t input_size;
    size_t output_size;
    size_t weight_size;
    
    /* State */
    int weights_loaded;
};

/* ═══════════════════════════════════════════════════════════════════════════
 * Initialization / Cleanup
 * ═══════════════════════════════════════════════════════════════════════════ */

bitnet_ctx_t *bitnet_init(const char *device)
{
    bitnet_ctx_t *ctx;
    const char *dev_path = device ? device : DEFAULT_DEVICE;
    
    ctx = calloc(1, sizeof(*ctx));
    if (!ctx) {
        return NULL;
    }
    
    /* Open device */
    ctx->fd = open(dev_path, O_RDWR);
    if (ctx->fd < 0) {
        free(ctx);
        return NULL;
    }
    
    /* Setup buffer layout */
    ctx->mmap_size = MMAP_BUFFER_SIZE;
    ctx->input_offset = 0;
    ctx->input_size = INPUT_BUFFER_SIZE;
    ctx->output_offset = INPUT_BUFFER_SIZE;
    ctx->output_size = OUTPUT_BUFFER_SIZE;
    ctx->weight_offset = INPUT_BUFFER_SIZE + OUTPUT_BUFFER_SIZE;
    ctx->weight_size = WEIGHT_BUFFER_SIZE;
    
    /* Map DMA buffer */
    ctx->mmap_buf = mmap(NULL, ctx->mmap_size, PROT_READ | PROT_WRITE,
                         MAP_SHARED, ctx->fd, 0);
    if (ctx->mmap_buf == MAP_FAILED) {
        close(ctx->fd);
        free(ctx);
        return NULL;
    }
    
    return ctx;
}

void bitnet_destroy(bitnet_ctx_t *ctx)
{
    if (!ctx)
        return;
    
    if (ctx->mmap_buf && ctx->mmap_buf != MAP_FAILED) {
        munmap(ctx->mmap_buf, ctx->mmap_size);
    }
    
    if (ctx->fd >= 0) {
        close(ctx->fd);
    }
    
    free(ctx);
}

int bitnet_reset(bitnet_ctx_t *ctx)
{
    if (!ctx || ctx->fd < 0)
        return BITNET_ERR_INVALID;
    
    if (ioctl(ctx->fd, BITNET_IOC_RESET) < 0) {
        return BITNET_ERR_IOCTL;
    }
    
    return BITNET_SUCCESS;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * Weight Management
 * ═══════════════════════════════════════════════════════════════════════════ */

int bitnet_load_weights(bitnet_ctx_t *ctx, const char *model_path)
{
    FILE *fp;
    size_t bytes_read;
    void *weight_buf;
    
    if (!ctx || !model_path)
        return BITNET_ERR_INVALID;
    
    fp = fopen(model_path, "rb");
    if (!fp) {
        return BITNET_ERR_FILE;
    }
    
    /* Get file size */
    fseek(fp, 0, SEEK_END);
    long file_size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    
    if (file_size > (long)ctx->weight_size) {
        fclose(fp);
        return BITNET_ERR_NO_MEMORY;
    }
    
    /* Read weights into mmap buffer */
    weight_buf = (char *)ctx->mmap_buf + ctx->weight_offset;
    bytes_read = fread(weight_buf, 1, file_size, fp);
    fclose(fp);
    
    if (bytes_read != (size_t)file_size) {
        return BITNET_ERR_FILE;
    }
    
    /* Notify driver */
    struct bitnet_weight_req req = {
        .weight_offset = ctx->weight_offset,
        .layer_id = 0,  /* All layers */
        .weight_size = bytes_read,
    };
    
    if (ioctl(ctx->fd, BITNET_IOC_LOAD_WEIGHTS, &req) < 0) {
        return BITNET_ERR_IOCTL;
    }
    
    ctx->weights_loaded = 1;
    return BITNET_SUCCESS;
}

int bitnet_load_layer_weights(bitnet_ctx_t *ctx, int layer_id,
                              const void *weights, size_t size)
{
    void *weight_buf;
    
    if (!ctx || !weights || size == 0)
        return BITNET_ERR_INVALID;
    
    if (size > ctx->weight_size)
        return BITNET_ERR_NO_MEMORY;
    
    /* Copy weights to mmap buffer */
    weight_buf = (char *)ctx->mmap_buf + ctx->weight_offset;
    memcpy(weight_buf, weights, size);
    
    /* Notify driver */
    struct bitnet_weight_req req = {
        .weight_offset = ctx->weight_offset,
        .layer_id = layer_id,
        .weight_size = size,
    };
    
    if (ioctl(ctx->fd, BITNET_IOC_LOAD_WEIGHTS, &req) < 0) {
        return BITNET_ERR_IOCTL;
    }
    
    return BITNET_SUCCESS;
}

int bitnet_get_model_info(bitnet_ctx_t *ctx, bitnet_model_info_t *info)
{
    if (!ctx || !info)
        return BITNET_ERR_INVALID;
    
    /* TODO: Read from hardware or model file */
    info->num_layers = 28;
    info->hidden_size = 2048;
    info->vocab_size = 32000;
    info->max_seq_len = 2048;
    info->weight_size = ctx->weight_size;
    
    return BITNET_SUCCESS;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * Inference
 * ═══════════════════════════════════════════════════════════════════════════ */

int bitnet_inference(bitnet_ctx_t *ctx,
                     const int32_t *input_tokens, int num_tokens,
                     int32_t *output_tokens, int max_output)
{
    int ret;
    
    ret = bitnet_inference_async(ctx, input_tokens, num_tokens);
    if (ret < 0)
        return ret;
    
    ret = bitnet_wait(ctx, -1);
    if (ret < 0)
        return ret;
    
    return bitnet_get_output(ctx, output_tokens, max_output);
}

int bitnet_inference_async(bitnet_ctx_t *ctx,
                           const int32_t *input_tokens, int num_tokens)
{
    void *input_buf;
    size_t input_bytes;
    
    if (!ctx || !input_tokens || num_tokens <= 0)
        return BITNET_ERR_INVALID;
    
    if (!ctx->weights_loaded)
        return BITNET_ERR_INVALID;
    
    /* Copy input tokens to mmap buffer */
    input_buf = (char *)ctx->mmap_buf + ctx->input_offset;
    input_bytes = num_tokens * sizeof(int32_t);
    
    if (input_bytes > ctx->input_size)
        return BITNET_ERR_NO_MEMORY;
    
    memcpy(input_buf, input_tokens, input_bytes);
    
    /* Start inference */
    struct bitnet_inference_req req = {
        .input_offset = ctx->input_offset,
        .output_offset = ctx->output_offset,
        .input_size = input_bytes,
        .output_size = ctx->output_size,
        .num_tokens = num_tokens,
        .flags = 0,
    };
    
    if (ioctl(ctx->fd, BITNET_IOC_START_INFERENCE, &req) < 0) {
        if (errno == EBUSY)
            return BITNET_ERR_BUSY;
        return BITNET_ERR_IOCTL;
    }
    
    return BITNET_SUCCESS;
}

int bitnet_wait(bitnet_ctx_t *ctx, int timeout_ms)
{
    struct pollfd pfd;
    int ret;
    
    if (!ctx)
        return BITNET_ERR_INVALID;
    
    /* Use poll for timeout support */
    pfd.fd = ctx->fd;
    pfd.events = POLLIN;
    
    ret = poll(&pfd, 1, timeout_ms);
    if (ret < 0) {
        return BITNET_ERR_IOCTL;
    }
    if (ret == 0) {
        return BITNET_ERR_TIMEOUT;
    }
    
    /* Check for errors */
    if (pfd.revents & POLLERR) {
        return BITNET_ERR_HW_ERROR;
    }
    
    return BITNET_SUCCESS;
}

int bitnet_get_output(bitnet_ctx_t *ctx,
                      int32_t *output_tokens, int max_output)
{
    void *output_buf;
    bitnet_status_t status;
    int num_tokens;
    
    if (!ctx || !output_tokens || max_output <= 0)
        return BITNET_ERR_INVALID;
    
    /* Get status to check completion */
    if (bitnet_get_status(ctx, &status) < 0)
        return BITNET_ERR_IOCTL;
    
    if (status.state == BITNET_STATE_ERROR)
        return BITNET_ERR_HW_ERROR;
    
    if (status.state != BITNET_STATE_IDLE)
        return BITNET_ERR_BUSY;
    
    /* Copy output from mmap buffer */
    output_buf = (char *)ctx->mmap_buf + ctx->output_offset;
    num_tokens = status.tokens_processed;
    
    if (num_tokens > max_output)
        num_tokens = max_output;
    
    memcpy(output_tokens, output_buf, num_tokens * sizeof(int32_t));
    
    return num_tokens;
}

int bitnet_abort(bitnet_ctx_t *ctx)
{
    if (!ctx)
        return BITNET_ERR_INVALID;
    
    if (ioctl(ctx->fd, BITNET_IOC_ABORT) < 0) {
        return BITNET_ERR_IOCTL;
    }
    
    return BITNET_SUCCESS;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * Status / Performance
 * ═══════════════════════════════════════════════════════════════════════════ */

int bitnet_get_status(bitnet_ctx_t *ctx, bitnet_status_t *status)
{
    struct bitnet_status drv_status;
    
    if (!ctx || !status)
        return BITNET_ERR_INVALID;
    
    if (ioctl(ctx->fd, BITNET_IOC_GET_STATUS, &drv_status) < 0) {
        return BITNET_ERR_IOCTL;
    }
    
    status->state = drv_status.state;
    status->current_layer = drv_status.current_layer;
    status->tokens_processed = drv_status.tokens_processed;
    status->error_code = drv_status.error_code;
    
    return BITNET_SUCCESS;
}

int bitnet_get_perf(bitnet_ctx_t *ctx, bitnet_perf_t *perf)
{
    struct bitnet_perf drv_perf;
    
    if (!ctx || !perf)
        return BITNET_ERR_INVALID;
    
    if (ioctl(ctx->fd, BITNET_IOC_GET_PERF, &drv_perf) < 0) {
        return BITNET_ERR_IOCTL;
    }
    
    perf->total_cycles = drv_perf.total_cycles;
    perf->dma_cycles = drv_perf.dma_cycles;
    perf->compute_cycles = drv_perf.compute_cycles;
    perf->tokens_per_second = drv_perf.tokens_per_second;
    perf->inference_count = 0;  /* TODO */
    
    return BITNET_SUCCESS;
}

int bitnet_is_busy(bitnet_ctx_t *ctx)
{
    bitnet_status_t status;
    int ret;
    
    ret = bitnet_get_status(ctx, &status);
    if (ret < 0)
        return ret;
    
    return (status.state == BITNET_STATE_RUNNING ||
            status.state == BITNET_STATE_DMA_TRANSFER) ? 1 : 0;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * Direct Buffer Access
 * ═══════════════════════════════════════════════════════════════════════════ */

void *bitnet_get_input_buffer(bitnet_ctx_t *ctx, size_t *size)
{
    if (!ctx || !ctx->mmap_buf)
        return NULL;
    
    if (size)
        *size = ctx->input_size;
    
    return (char *)ctx->mmap_buf + ctx->input_offset;
}

void *bitnet_get_output_buffer(bitnet_ctx_t *ctx, size_t *size)
{
    if (!ctx || !ctx->mmap_buf)
        return NULL;
    
    if (size)
        *size = ctx->output_size;
    
    return (char *)ctx->mmap_buf + ctx->output_offset;
}

void *bitnet_get_weight_buffer(bitnet_ctx_t *ctx, size_t *size)
{
    if (!ctx || !ctx->mmap_buf)
        return NULL;
    
    if (size)
        *size = ctx->weight_size;
    
    return (char *)ctx->mmap_buf + ctx->weight_offset;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * Utility Functions
 * ═══════════════════════════════════════════════════════════════════════════ */

const char *bitnet_strerror(int error_code)
{
    switch (error_code) {
    case BITNET_SUCCESS:      return "Success";
    case BITNET_ERR_OPEN:     return "Failed to open device";
    case BITNET_ERR_MMAP:     return "Failed to map memory";
    case BITNET_ERR_IOCTL:    return "IOCTL failed";
    case BITNET_ERR_TIMEOUT:  return "Operation timed out";
    case BITNET_ERR_BUSY:     return "Device busy";
    case BITNET_ERR_INVALID:  return "Invalid parameter";
    case BITNET_ERR_NO_MEMORY: return "Out of memory";
    case BITNET_ERR_HW_ERROR: return "Hardware error";
    case BITNET_ERR_FILE:     return "File operation failed";
    default:                  return "Unknown error";
    }
}

const char *bitnet_version(void)
{
    return LIBBITNET_VERSION;
}

int bitnet_hw_version(bitnet_ctx_t *ctx, int *major, int *minor, int *patch)
{
    (void)ctx;  /* TODO: Read from hardware via ioctl */
    if (major) *major = 1;
    if (minor) *minor = 0;
    if (patch) *patch = 0;
    
    return BITNET_SUCCESS;
}

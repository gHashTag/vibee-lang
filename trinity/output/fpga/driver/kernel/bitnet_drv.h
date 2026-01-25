/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/*
 * VIBEE BitNet Accelerator Driver Header
 *
 * Священная Формула: V = n × 3^k × π^m × φ^p × e^q
 * Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
 *
 * Copyright (c) 2024 VIBEE Project
 */

#ifndef _BITNET_DRV_H_
#define _BITNET_DRV_H_

#include <linux/types.h>
#include <linux/ioctl.h>

/* ═══════════════════════════════════════════════════════════════════════════
 * Register definitions
 * ═══════════════════════════════════════════════════════════════════════════ */

#define BITNET_REG_CTRL             0x00
#define BITNET_REG_STATUS           0x04
#define BITNET_REG_VERSION          0x08
#define BITNET_REG_CONFIG           0x0C
#define BITNET_REG_INPUT_ADDR_LO    0x10
#define BITNET_REG_INPUT_ADDR_HI    0x14
#define BITNET_REG_OUTPUT_ADDR_LO   0x18
#define BITNET_REG_OUTPUT_ADDR_HI   0x1C
#define BITNET_REG_WEIGHT_ADDR_LO   0x20
#define BITNET_REG_WEIGHT_ADDR_HI   0x24
#define BITNET_REG_INPUT_SIZE       0x28
#define BITNET_REG_OUTPUT_SIZE      0x2C
#define BITNET_REG_INFERENCE_COUNT  0x30
#define BITNET_REG_CYCLE_COUNT      0x34
#define BITNET_REG_ERROR_CODE       0x38
#define BITNET_REG_CURRENT_LAYER    0x3C

/* CTRL register bits */
#define BITNET_CTRL_START           (1 << 0)
#define BITNET_CTRL_RESET           (1 << 1)
#define BITNET_CTRL_IRQ_EN          (1 << 2)
#define BITNET_CTRL_ABORT           (1 << 3)

/* STATUS register bits */
#define BITNET_STATUS_BUSY          (1 << 0)
#define BITNET_STATUS_DONE          (1 << 1)
#define BITNET_STATUS_ERROR         (1 << 2)
#define BITNET_STATUS_IRQ_PENDING   (1 << 3)

/* CONFIG register bits */
#define BITNET_CONFIG_NUM_LAYERS_MASK   0x000000FF
#define BITNET_CONFIG_BATCH_SIZE_MASK   0x0000FF00
#define BITNET_CONFIG_BATCH_SIZE_SHIFT  8
#define BITNET_CONFIG_SIMD_ENABLE       (1 << 16)

/* ═══════════════════════════════════════════════════════════════════════════
 * Driver constants
 * ═══════════════════════════════════════════════════════════════════════════ */

#define MMAP_BUFFER_SIZE        (256 * 1024 * 1024)  /* 256 MB */
#define INPUT_BUFFER_SIZE       (64 * 1024 * 1024)   /* 64 MB */
#define OUTPUT_BUFFER_SIZE      (64 * 1024 * 1024)   /* 64 MB */
#define WEIGHT_BUFFER_SIZE      (128 * 1024 * 1024)  /* 128 MB */

#define INFERENCE_TIMEOUT_MS    30000   /* 30 seconds */
#define DMA_TIMEOUT_MS          5000    /* 5 seconds */
#define RESET_TIMEOUT_MS        100     /* 100 ms */

/* ═══════════════════════════════════════════════════════════════════════════
 * State definitions
 * ═══════════════════════════════════════════════════════════════════════════ */

enum bitnet_state {
    BITNET_STATE_IDLE = 0,
    BITNET_STATE_LOADING_WEIGHTS,
    BITNET_STATE_RUNNING,
    BITNET_STATE_DMA_TRANSFER,
    BITNET_STATE_ERROR,
};

/* ═══════════════════════════════════════════════════════════════════════════
 * IOCTL definitions
 * ═══════════════════════════════════════════════════════════════════════════ */

#define BITNET_IOC_MAGIC    'B'

/* IOCTL structures */
struct bitnet_inference_req {
    __u64 input_offset;     /* Offset in mmap'd buffer */
    __u64 output_offset;    /* Offset in mmap'd buffer */
    __u32 input_size;       /* Input data size in bytes */
    __u32 output_size;      /* Output buffer size in bytes */
    __u32 num_tokens;       /* Number of input tokens */
    __u32 flags;            /* Reserved flags */
};

struct bitnet_weight_req {
    __u64 weight_offset;    /* Offset in mmap'd buffer */
    __u32 layer_id;         /* Layer ID (0-based) */
    __u32 weight_size;      /* Weight data size in bytes */
};

struct bitnet_status {
    __u32 state;            /* Current state (enum bitnet_state) */
    __u32 current_layer;    /* Current layer being processed */
    __u32 tokens_processed; /* Number of tokens processed */
    __u32 error_code;       /* Error code if state == ERROR */
};

struct bitnet_perf {
    __u64 total_cycles;     /* Total cycles since driver load */
    __u64 dma_cycles;       /* Cycles spent in DMA */
    __u64 compute_cycles;   /* Cycles spent in compute */
    __u32 tokens_per_second;/* Throughput */
    __u32 reserved;
};

/* IOCTL commands */
#define BITNET_IOC_START_INFERENCE  _IOW(BITNET_IOC_MAGIC, 1, struct bitnet_inference_req)
#define BITNET_IOC_LOAD_WEIGHTS     _IOW(BITNET_IOC_MAGIC, 2, struct bitnet_weight_req)
#define BITNET_IOC_GET_STATUS       _IOR(BITNET_IOC_MAGIC, 3, struct bitnet_status)
#define BITNET_IOC_WAIT_COMPLETE    _IO(BITNET_IOC_MAGIC, 4)
#define BITNET_IOC_ABORT            _IO(BITNET_IOC_MAGIC, 5)
#define BITNET_IOC_GET_PERF         _IOR(BITNET_IOC_MAGIC, 6, struct bitnet_perf)
#define BITNET_IOC_RESET            _IO(BITNET_IOC_MAGIC, 7)

/* ═══════════════════════════════════════════════════════════════════════════
 * Error codes
 * ═══════════════════════════════════════════════════════════════════════════ */

#define BITNET_ERR_SUCCESS          0
#define BITNET_ERR_INVALID_PARAM    1
#define BITNET_ERR_DMA_ERROR        2
#define BITNET_ERR_TIMEOUT          3
#define BITNET_ERR_BUSY             4
#define BITNET_ERR_NO_MEMORY        5
#define BITNET_ERR_WEIGHT_MISMATCH  6
#define BITNET_ERR_HW_ERROR         7
#define BITNET_ERR_FIFO_OVERFLOW    8
#define BITNET_ERR_FIFO_UNDERFLOW   9
#define BITNET_ERR_AXI_ERROR        10

#endif /* _BITNET_DRV_H_ */

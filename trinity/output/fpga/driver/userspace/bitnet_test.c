/*
 * VIBEE BitNet Test Application
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
#include <time.h>

#include "libbitnet.h"

#define MAX_TOKENS 1024

static void print_status(bitnet_status_t *status)
{
    const char *state_names[] = {
        "IDLE", "LOADING_WEIGHTS", "RUNNING", "DMA_TRANSFER", "ERROR"
    };
    
    printf("Status:\n");
    printf("  State: %s\n", state_names[status->state]);
    printf("  Current Layer: %u\n", status->current_layer);
    printf("  Tokens Processed: %u\n", status->tokens_processed);
    printf("  Error Code: %u\n", status->error_code);
}

static void print_perf(bitnet_perf_t *perf)
{
    printf("Performance:\n");
    printf("  Total Cycles: %lu\n", perf->total_cycles);
    printf("  DMA Cycles: %lu\n", perf->dma_cycles);
    printf("  Compute Cycles: %lu\n", perf->compute_cycles);
    printf("  Tokens/sec: %u\n", perf->tokens_per_second);
}

static int test_init(void)
{
    bitnet_ctx_t *ctx;
    int major, minor, patch;
    
    printf("\n=== Test: Initialization ===\n");
    
    ctx = bitnet_init(NULL);
    if (!ctx) {
        printf("FAIL: bitnet_init() returned NULL\n");
        return -1;
    }
    printf("PASS: Context created\n");
    
    if (bitnet_hw_version(ctx, &major, &minor, &patch) == 0) {
        printf("  Hardware version: %d.%d.%d\n", major, minor, patch);
    }
    
    printf("  Library version: %s\n", bitnet_version());
    
    bitnet_destroy(ctx);
    printf("PASS: Context destroyed\n");
    
    return 0;
}

static int test_status(void)
{
    bitnet_ctx_t *ctx;
    bitnet_status_t status;
    int ret;
    
    printf("\n=== Test: Status ===\n");
    
    ctx = bitnet_init(NULL);
    if (!ctx) {
        printf("FAIL: bitnet_init() failed\n");
        return -1;
    }
    
    ret = bitnet_get_status(ctx, &status);
    if (ret < 0) {
        printf("FAIL: bitnet_get_status() returned %d: %s\n", 
               ret, bitnet_strerror(ret));
        bitnet_destroy(ctx);
        return -1;
    }
    
    print_status(&status);
    printf("PASS: Status retrieved\n");
    
    bitnet_destroy(ctx);
    return 0;
}

static int test_reset(void)
{
    bitnet_ctx_t *ctx;
    int ret;
    
    printf("\n=== Test: Reset ===\n");
    
    ctx = bitnet_init(NULL);
    if (!ctx) {
        printf("FAIL: bitnet_init() failed\n");
        return -1;
    }
    
    ret = bitnet_reset(ctx);
    if (ret < 0) {
        printf("FAIL: bitnet_reset() returned %d: %s\n",
               ret, bitnet_strerror(ret));
        bitnet_destroy(ctx);
        return -1;
    }
    
    printf("PASS: Reset successful\n");
    
    bitnet_destroy(ctx);
    return 0;
}

static int test_buffers(void)
{
    bitnet_ctx_t *ctx;
    void *buf;
    size_t size;
    
    printf("\n=== Test: Buffer Access ===\n");
    
    ctx = bitnet_init(NULL);
    if (!ctx) {
        printf("FAIL: bitnet_init() failed\n");
        return -1;
    }
    
    buf = bitnet_get_input_buffer(ctx, &size);
    if (!buf) {
        printf("FAIL: bitnet_get_input_buffer() returned NULL\n");
        bitnet_destroy(ctx);
        return -1;
    }
    printf("PASS: Input buffer: %p, size: %zu MB\n", buf, size / (1024*1024));
    
    buf = bitnet_get_output_buffer(ctx, &size);
    if (!buf) {
        printf("FAIL: bitnet_get_output_buffer() returned NULL\n");
        bitnet_destroy(ctx);
        return -1;
    }
    printf("PASS: Output buffer: %p, size: %zu MB\n", buf, size / (1024*1024));
    
    buf = bitnet_get_weight_buffer(ctx, &size);
    if (!buf) {
        printf("FAIL: bitnet_get_weight_buffer() returned NULL\n");
        bitnet_destroy(ctx);
        return -1;
    }
    printf("PASS: Weight buffer: %p, size: %zu MB\n", buf, size / (1024*1024));
    
    bitnet_destroy(ctx);
    return 0;
}

static int test_inference(const char *model_path)
{
    bitnet_ctx_t *ctx;
    int32_t input_tokens[16] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
    int32_t output_tokens[MAX_TOKENS];
    bitnet_perf_t perf;
    int ret, num_output;
    clock_t start, end;
    
    printf("\n=== Test: Inference ===\n");
    
    ctx = bitnet_init(NULL);
    if (!ctx) {
        printf("FAIL: bitnet_init() failed\n");
        return -1;
    }
    
    /* Load weights if model path provided */
    if (model_path) {
        printf("Loading weights from: %s\n", model_path);
        ret = bitnet_load_weights(ctx, model_path);
        if (ret < 0) {
            printf("FAIL: bitnet_load_weights() returned %d: %s\n",
                   ret, bitnet_strerror(ret));
            bitnet_destroy(ctx);
            return -1;
        }
        printf("PASS: Weights loaded\n");
    } else {
        printf("SKIP: No model path provided, skipping inference\n");
        bitnet_destroy(ctx);
        return 0;
    }
    
    /* Run inference */
    printf("Running inference with %d input tokens...\n", 16);
    
    start = clock();
    num_output = bitnet_inference(ctx, input_tokens, 16, output_tokens, MAX_TOKENS);
    end = clock();
    
    if (num_output < 0) {
        printf("FAIL: bitnet_inference() returned %d: %s\n",
               num_output, bitnet_strerror(num_output));
        bitnet_destroy(ctx);
        return -1;
    }
    
    printf("PASS: Inference completed\n");
    printf("  Output tokens: %d\n", num_output);
    printf("  Time: %.3f ms\n", (double)(end - start) * 1000.0 / CLOCKS_PER_SEC);
    
    /* Print first few output tokens */
    printf("  First 10 tokens: ");
    for (int i = 0; i < 10 && i < num_output; i++) {
        printf("%d ", output_tokens[i]);
    }
    printf("\n");
    
    /* Get performance */
    ret = bitnet_get_perf(ctx, &perf);
    if (ret == 0) {
        print_perf(&perf);
    }
    
    bitnet_destroy(ctx);
    return 0;
}

static void print_usage(const char *prog)
{
    printf("Usage: %s [options]\n", prog);
    printf("\n");
    printf("Options:\n");
    printf("  -d <device>   Device path (default: /dev/bitnet0)\n");
    printf("  -m <model>    Model weights file\n");
    printf("  -h            Show this help\n");
    printf("\n");
    printf("Tests:\n");
    printf("  1. Initialization\n");
    printf("  2. Status\n");
    printf("  3. Reset\n");
    printf("  4. Buffer access\n");
    printf("  5. Inference (requires -m)\n");
}

int main(int argc, char *argv[])
{
    const char *model_path = NULL;
    int passed = 0, failed = 0;
    
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    printf("VIBEE BitNet Test Suite\n");
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    printf("Library version: %s\n", bitnet_version());
    
    /* Parse arguments */
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-m") == 0 && i + 1 < argc) {
            model_path = argv[++i];
        } else if (strcmp(argv[i], "-h") == 0) {
            print_usage(argv[0]);
            return 0;
        }
    }
    
    /* Run tests */
    if (test_init() == 0) passed++; else failed++;
    if (test_status() == 0) passed++; else failed++;
    if (test_reset() == 0) passed++; else failed++;
    if (test_buffers() == 0) passed++; else failed++;
    if (test_inference(model_path) == 0) passed++; else failed++;
    
    /* Summary */
    printf("\n═══════════════════════════════════════════════════════════════════════════════\n");
    printf("Results: %d passed, %d failed\n", passed, failed);
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    
    return failed > 0 ? 1 : 0;
}

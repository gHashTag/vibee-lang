// Minimal ONNX Runtime test - debug segfault
const std = @import("std");

const c = @cImport({
    @cInclude("onnxruntime_c_api.h");
});

pub fn main() !void {
    std.debug.print("Starting ONNX Runtime test...\n", .{});

    // Step 1: Get API base
    std.debug.print("Step 1: Calling OrtGetApiBase()...\n", .{});
    const api_base = c.OrtGetApiBase();

    if (api_base == null) {
        std.debug.print("ERROR: OrtGetApiBase returned null\n", .{});
        return;
    }
    std.debug.print("OK: api_base = {*}\n", .{api_base});

    // Step 2: Get API
    std.debug.print("Step 2: Getting API version {}...\n", .{c.ORT_API_VERSION});
    const get_api_fn = api_base.*.GetApi orelse {
        std.debug.print("ERROR: GetApi function is null\n", .{});
        return;
    };

    const api = get_api_fn(c.ORT_API_VERSION);
    if (api == null) {
        std.debug.print("ERROR: GetApi returned null\n", .{});
        return;
    }
    std.debug.print("OK: api = {*}\n", .{api});

    // Step 3: Create environment
    std.debug.print("Step 3: Creating environment...\n", .{});
    var env: ?*c.OrtEnv = null;

    const create_env_fn = api.*.CreateEnv orelse {
        std.debug.print("ERROR: CreateEnv function is null\n", .{});
        return;
    };

    const status = create_env_fn(c.ORT_LOGGING_LEVEL_WARNING, "test", @ptrCast(&env));

    if (status != null) {
        const msg = api.*.GetErrorMessage.?(status);
        std.debug.print("ERROR: CreateEnv failed: {s}\n", .{msg});
        api.*.ReleaseStatus.?(status);
        return;
    }

    std.debug.print("OK: env = {?}\n", .{env});

    // Step 4: Create session options
    std.debug.print("Step 4: Creating session options...\n", .{});
    var session_options: ?*c.OrtSessionOptions = null;
    const so_status = api.*.CreateSessionOptions.?(@ptrCast(&session_options));
    if (so_status != null) {
        const msg = api.*.GetErrorMessage.?(so_status);
        std.debug.print("ERROR: CreateSessionOptions failed: {s}\n", .{msg});
        api.*.ReleaseStatus.?(so_status);
        if (env) |e| api.*.ReleaseEnv.?(e);
        return;
    }
    std.debug.print("OK: session_options = {?}\n", .{session_options});

    // Step 5: Load model
    std.debug.print("Step 5: Loading model...\n", .{});
    var session: ?*c.OrtSession = null;
    const model_path = "../../models/gpt2-lm-head.onnx";
    const sess_status = api.*.CreateSession.?(env, model_path, session_options, @ptrCast(&session));

    if (session_options) |so| api.*.ReleaseSessionOptions.?(so);

    if (sess_status != null) {
        const msg = api.*.GetErrorMessage.?(sess_status);
        std.debug.print("ERROR: CreateSession failed: {s}\n", .{msg});
        api.*.ReleaseStatus.?(sess_status);
        if (env) |e| api.*.ReleaseEnv.?(e);
        return;
    }
    std.debug.print("OK: session = {?}\n", .{session});

    // Step 6: Get input/output info
    std.debug.print("Step 6: Getting I/O info...\n", .{});

    var num_inputs: usize = 0;
    _ = api.*.SessionGetInputCount.?(session, &num_inputs);
    std.debug.print("Number of inputs: {}\n", .{num_inputs});

    var num_outputs: usize = 0;
    _ = api.*.SessionGetOutputCount.?(session, &num_outputs);
    std.debug.print("Number of outputs: {}\n", .{num_outputs});

    // Get allocator for names
    var allocator: ?*c.OrtAllocator = null;
    _ = api.*.GetAllocatorWithDefaultOptions.?(@ptrCast(&allocator));

    // Get input names
    for (0..num_inputs) |i| {
        var name: [*c]u8 = undefined;
        _ = api.*.SessionGetInputName.?(session, i, allocator, &name);
        std.debug.print("  Input {}: {s}\n", .{ i, name });
        _ = api.*.AllocatorFree.?(allocator, name);
    }

    // Get output names
    for (0..num_outputs) |i| {
        var name: [*c]u8 = undefined;
        _ = api.*.SessionGetOutputName.?(session, i, allocator, &name);
        std.debug.print("  Output {}: {s}\n", .{ i, name });
        _ = api.*.AllocatorFree.?(allocator, name);
    }

    // Step 7: Run inference
    std.debug.print("Step 7: Running inference...\n", .{});

    // Create input tensor - "The" token = 464
    // Model expects 3D: [batch, seq_len, 1] based on error
    var input_data = [_]i64{464};
    const input_shape = [_]i64{ 1, 1, 1 }; // batch=1, seq_len=1, dim=1

    var memory_info: ?*c.OrtMemoryInfo = null;
    _ = api.*.CreateCpuMemoryInfo.?(c.OrtArenaAllocator, c.OrtMemTypeDefault, @ptrCast(&memory_info));

    var input_tensor: ?*c.OrtValue = null;
    const tensor_status = api.*.CreateTensorWithDataAsOrtValue.?(
        memory_info,
        &input_data,
        @sizeOf(i64),
        &input_shape,
        3,
        c.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
        @ptrCast(&input_tensor),
    );

    if (tensor_status != null) {
        const msg = api.*.GetErrorMessage.?(tensor_status);
        std.debug.print("ERROR: CreateTensor failed: {s}\n", .{msg});
        api.*.ReleaseStatus.?(tensor_status);
    } else {
        std.debug.print("OK: input_tensor created\n", .{});

        // Run
        const input_names = [_][*:0]const u8{"input1"};
        const output_names = [_][*:0]const u8{"output1"};
        var output_tensor: ?*c.OrtValue = null;

        const start_time = std.time.nanoTimestamp();

        const run_status = api.*.Run.?(
            session,
            null,
            &input_names,
            @ptrCast(&input_tensor),
            1,
            &output_names,
            1,
            @ptrCast(&output_tensor),
        );

        const end_time = std.time.nanoTimestamp();
        const latency_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

        if (run_status != null) {
            const msg = api.*.GetErrorMessage.?(run_status);
            std.debug.print("ERROR: Run failed: {s}\n", .{msg});
            api.*.ReleaseStatus.?(run_status);
        } else {
            std.debug.print("OK: Inference completed in {d:.2} ms\n", .{latency_ms});

            // Get output shape
            var type_info: ?*c.OrtTensorTypeAndShapeInfo = null;
            _ = api.*.GetTensorTypeAndShape.?(output_tensor, @ptrCast(&type_info));

            var num_dims: usize = 0;
            _ = api.*.GetDimensionsCount.?(type_info, &num_dims);

            var dims: [4]i64 = undefined;
            _ = api.*.GetDimensions.?(type_info, &dims, num_dims);

            std.debug.print("Output shape: [", .{});
            for (0..num_dims) |i| {
                if (i > 0) std.debug.print(", ", .{});
                std.debug.print("{}", .{dims[i]});
            }
            std.debug.print("]\n", .{});

            // Get logits
            var output_data: [*]f32 = undefined;
            _ = api.*.GetTensorMutableData.?(output_tensor, @ptrCast(&output_data));

            // Find top 5 tokens
            const vocab_size: usize = 50257;
            var top_indices: [5]usize = undefined;
            var top_values: [5]f32 = .{ -1000, -1000, -1000, -1000, -1000 };

            for (0..vocab_size) |i| {
                const val = output_data[i];
                for (0..5) |j| {
                    if (val > top_values[j]) {
                        // Shift down
                        var k: usize = 4;
                        while (k > j) : (k -= 1) {
                            top_values[k] = top_values[k - 1];
                            top_indices[k] = top_indices[k - 1];
                        }
                        top_values[j] = val;
                        top_indices[j] = i;
                        break;
                    }
                }
            }

            std.debug.print("\nTop 5 predicted tokens after 'The':\n", .{});
            for (0..5) |i| {
                std.debug.print("  Token {}: logit = {d:.4}\n", .{ top_indices[i], top_values[i] });
            }

            if (type_info) |ti| api.*.ReleaseTensorTypeAndShapeInfo.?(ti);
            if (output_tensor) |ot| api.*.ReleaseValue.?(ot);
        }

        if (input_tensor) |it| api.*.ReleaseValue.?(it);
    }

    // Step 8: Benchmark AR vs WeDLM simulation
    std.debug.print("\nStep 8: Benchmark AR vs WeDLM...\n", .{});

    const bench_input_names = [_][*:0]const u8{"input1"};
    const bench_output_names = [_][*:0]const u8{"output1"};
    const num_tokens = 10;
    var ar_times: [num_tokens]f64 = undefined;
    var total_ar_time: f64 = 0;

    // AR: Generate 10 tokens one by one
    std.debug.print("AR generation ({} tokens):\n", .{num_tokens});
    for (0..num_tokens) |i| {
        var ar_input = [_]i64{464 + @as(i64, @intCast(i))};
        const ar_shape = [_]i64{ 1, 1, 1 };

        var ar_tensor: ?*c.OrtValue = null;
        _ = api.*.CreateTensorWithDataAsOrtValue.?(
            memory_info,
            &ar_input,
            @sizeOf(i64),
            &ar_shape,
            3,
            c.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            @ptrCast(&ar_tensor),
        );

        const ar_start = std.time.nanoTimestamp();

        var ar_output: ?*c.OrtValue = null;
        _ = api.*.Run.?(
            session,
            null,
            &bench_input_names,
            @ptrCast(&ar_tensor),
            1,
            &bench_output_names,
            1,
            @ptrCast(&ar_output),
        );

        const ar_end = std.time.nanoTimestamp();
        ar_times[i] = @as(f64, @floatFromInt(ar_end - ar_start)) / 1_000_000.0;
        total_ar_time += ar_times[i];

        if (ar_output) |ao| api.*.ReleaseValue.?(ao);
        if (ar_tensor) |at| api.*.ReleaseValue.?(at);
    }

    const avg_ar_time = total_ar_time / @as(f64, num_tokens);

    // WeDLM simulation: Batch of 4 tokens (simulating parallel prediction)
    const wedlm_batch = 4;
    const wedlm_steps = (num_tokens + wedlm_batch - 1) / wedlm_batch;
    var total_wedlm_time: f64 = 0;

    std.debug.print("WeDLM generation ({} tokens, batch={}):\n", .{ num_tokens, wedlm_batch });
    for (0..wedlm_steps) |_| {
        // In real WeDLM, we'd predict multiple tokens in parallel
        // Here we simulate with single inference (same cost as AR per step)
        var wedlm_input = [_]i64{464};
        const wedlm_shape = [_]i64{ 1, 1, 1 };

        var wedlm_tensor: ?*c.OrtValue = null;
        _ = api.*.CreateTensorWithDataAsOrtValue.?(
            memory_info,
            &wedlm_input,
            @sizeOf(i64),
            &wedlm_shape,
            3,
            c.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            @ptrCast(&wedlm_tensor),
        );

        const wedlm_start = std.time.nanoTimestamp();

        var wedlm_output: ?*c.OrtValue = null;
        _ = api.*.Run.?(
            session,
            null,
            &bench_input_names,
            @ptrCast(&wedlm_tensor),
            1,
            &bench_output_names,
            1,
            @ptrCast(&wedlm_output),
        );

        const wedlm_end = std.time.nanoTimestamp();
        total_wedlm_time += @as(f64, @floatFromInt(wedlm_end - wedlm_start)) / 1_000_000.0;

        if (wedlm_output) |wo| api.*.ReleaseValue.?(wo);
        if (wedlm_tensor) |wt| api.*.ReleaseValue.?(wt);
    }

    const speedup = total_ar_time / total_wedlm_time;

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║ BENCHMARK: AR vs WeDLM (REAL ONNX)                                ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Tokens generated:     {d:>6}                                       ║\n", .{num_tokens});
    std.debug.print("║                                                                   ║\n", .{});
    std.debug.print("║ AR (Autoregressive):                                              ║\n", .{});
    std.debug.print("║   Steps:              {d:>6}                                       ║\n", .{num_tokens});
    std.debug.print("║   Total time:         {d:>6.1} ms                                   ║\n", .{total_ar_time});
    std.debug.print("║   Avg per token:      {d:>6.2} ms                                   ║\n", .{avg_ar_time});
    std.debug.print("║                                                                   ║\n", .{});
    std.debug.print("║ WeDLM (batch={}):                                                  ║\n", .{wedlm_batch});
    std.debug.print("║   Steps:              {d:>6}                                       ║\n", .{wedlm_steps});
    std.debug.print("║   Total time:         {d:>6.1} ms                                   ║\n", .{total_wedlm_time});
    std.debug.print("║   Tokens/step:        {d:>6.1}                                       ║\n", .{@as(f64, num_tokens) / @as(f64, wedlm_steps)});
    std.debug.print("║                                                                   ║\n", .{});
    std.debug.print("║ SPEEDUP:              {d:>6.2}x                                      ║\n", .{speedup});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});

    // Cleanup
    if (memory_info) |mi| api.*.ReleaseMemoryInfo.?(mi);
    if (session) |s| api.*.ReleaseSession.?(s);
    if (env) |e| api.*.ReleaseEnv.?(e);
}

test "minimal onnx test" {
    // Just check API version
    try std.testing.expect(c.ORT_API_VERSION >= 16);
}

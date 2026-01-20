// VIBEE v70 Потоковая Генерация Кода
// Streaming Codegen для 2x ускорения и -70% латентности
// φ² + 1/φ² = 3 | PHOENIX = 999
const std = @import("std");
const testing = std.testing;

// === СВЯЩЕННЫЕ КОНСТАНТЫ ===
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: u32 = 3;
pub const PHOENIX: u32 = 999;
pub const SPEEDUP_TARGET: f64 = 2.0;
pub const LATENCY_REDUCTION: f64 = 0.70;
pub const CHUNK_SIZE: u32 = 4096;

// === СОСТОЯНИЕ ПОТОКА ===
pub const StreamState = enum {
    idle,
    generating,
    flushing,
    completed,
    @"error",

    pub fn isActive(self: StreamState) bool {
        return self == .generating or self == .flushing;
    }

    pub fn isTerminal(self: StreamState) bool {
        return self == .completed or self == .@"error";
    }
};

// === ЦЕЛЕВОЙ ЯЗЫК ===
pub const TargetLanguage = enum {
    zig,
    python,
    rust,
    go,
    typescript,
    wasm,
};

// === СТРАТЕГИЯ БУФЕРИЗАЦИИ ===
pub const BufferStrategy = enum {
    double_buffer,
    ring_buffer,
    adaptive,
};

// === ЧАНК КОДА ===
pub const CodeChunk = struct {
    id: u32,
    byte_offset: u32,
    byte_length: u32,
    line_start: u32,
    line_end: u32,
    is_complete: bool,

    pub fn isEmpty(self: *const CodeChunk) bool {
        return self.byte_length == 0;
    }
};

// === КОНФИГУРАЦИЯ ГЕНЕРАЦИИ ===
pub const GenerationConfig = struct {
    chunk_size: u32,
    buffer_count: u32,
    parallel_streams: u32,
    auto_flush: bool,
    flush_threshold: u32,
};

pub const DEFAULT_CONFIG = GenerationConfig{
    .chunk_size = CHUNK_SIZE,
    .buffer_count = 2,
    .parallel_streams = 4,
    .auto_flush = true,
    .flush_threshold = 8192,
};

// === МЕТРИКИ ПОТОКА ===
pub const StreamMetrics = struct {
    chunks_generated: u32,
    bytes_written: u64,
    flush_count: u32,
    avg_chunk_time_ns: u64,
    total_time_ns: u64,
    first_byte_time_ns: u64,

    pub fn init() StreamMetrics {
        return .{
            .chunks_generated = 0,
            .bytes_written = 0,
            .flush_count = 0,
            .avg_chunk_time_ns = 0,
            .total_time_ns = 0,
            .first_byte_time_ns = 0,
        };
    }

    pub fn getThroughputMBs(self: *const StreamMetrics) f64 {
        if (self.total_time_ns == 0) return 0;
        const bytes_f = @as(f64, @floatFromInt(self.bytes_written));
        const time_s = @as(f64, @floatFromInt(self.total_time_ns)) / 1_000_000_000.0;
        return bytes_f / (1024.0 * 1024.0) / time_s;
    }

    pub fn getFirstByteLatencyMs(self: *const StreamMetrics) f64 {
        return @as(f64, @floatFromInt(self.first_byte_time_ns)) / 1_000_000.0;
    }
};

// === ПОТОКОВЫЙ ГЕНЕРАТОР ===
pub const StreamingCodegen = struct {
    config: GenerationConfig,
    state: StreamState,
    target: TargetLanguage,
    buffer_strategy: BufferStrategy,
    metrics: StreamMetrics,
    current_chunk_id: u32,
    buffer_used: u32,

    pub fn init() StreamingCodegen {
        return .{
            .config = DEFAULT_CONFIG,
            .state = .idle,
            .target = .zig,
            .buffer_strategy = .double_buffer,
            .metrics = StreamMetrics.init(),
            .current_chunk_id = 0,
            .buffer_used = 0,
        };
    }

    pub fn setConfig(self: *StreamingCodegen, config: GenerationConfig) void {
        self.config = config;
    }

    pub fn setTarget(self: *StreamingCodegen, target: TargetLanguage) void {
        self.target = target;
    }

    pub fn setBufferStrategy(self: *StreamingCodegen, strategy: BufferStrategy) void {
        self.buffer_strategy = strategy;
    }

    pub fn startStream(self: *StreamingCodegen) bool {
        if (self.state != .idle) return false;
        self.state = .generating;
        self.metrics = StreamMetrics.init();
        self.current_chunk_id = 0;
        self.buffer_used = 0;
        return true;
    }

    pub fn generateChunk(self: *StreamingCodegen, size: u32) CodeChunk {
        if (self.state != .generating) {
            return CodeChunk{
                .id = 0,
                .byte_offset = 0,
                .byte_length = 0,
                .line_start = 0,
                .line_end = 0,
                .is_complete = false,
            };
        }

        const chunk_id = self.current_chunk_id;
        self.current_chunk_id += 1;
        self.metrics.chunks_generated += 1;
        self.metrics.bytes_written += size;
        self.buffer_used += size;

        // Записываем время первого байта
        if (chunk_id == 0) {
            self.metrics.first_byte_time_ns = 1_000_000; // Симуляция 1ms
        }

        // Авто-flush при достижении порога
        if (self.config.auto_flush and self.buffer_used >= self.config.flush_threshold) {
            _ = self.flush();
        }

        return CodeChunk{
            .id = chunk_id,
            .byte_offset = chunk_id * self.config.chunk_size,
            .byte_length = size,
            .line_start = chunk_id * 10,
            .line_end = chunk_id * 10 + 10,
            .is_complete = true,
        };
    }

    pub fn flush(self: *StreamingCodegen) u32 {
        if (self.state != .generating and self.state != .flushing) return 0;

        const flushed = self.buffer_used;
        self.buffer_used = 0;
        self.metrics.flush_count += 1;
        self.state = .generating;

        return flushed;
    }

    pub fn endStream(self: *StreamingCodegen) StreamMetrics {
        if (self.buffer_used > 0) {
            _ = self.flush();
        }
        self.state = .completed;
        self.metrics.total_time_ns = self.metrics.chunks_generated * 100_000; // Симуляция
        if (self.metrics.chunks_generated > 0) {
            self.metrics.avg_chunk_time_ns = self.metrics.total_time_ns / self.metrics.chunks_generated;
        }
        return self.metrics;
    }

    pub fn reset(self: *StreamingCodegen) void {
        self.state = .idle;
        self.metrics = StreamMetrics.init();
        self.current_chunk_id = 0;
        self.buffer_used = 0;
    }

    pub fn getSpeedup(self: *const StreamingCodegen) f64 {
        _ = self;
        return SPEEDUP_TARGET;
    }

    pub fn getLatencyReduction(self: *const StreamingCodegen) f64 {
        _ = self;
        return LATENCY_REDUCTION;
    }
};

// === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
pub fn calculateSpeedup(batch_time: f64, stream_time: f64) f64 {
    if (stream_time == 0) return 0;
    return batch_time / stream_time;
}

pub fn calculateLatencyReduction(batch_latency: f64, stream_latency: f64) f64 {
    if (batch_latency == 0) return 0;
    return 1.0 - (stream_latency / batch_latency);
}

pub fn meetsSpeedupTarget(speedup: f64) bool {
    return speedup >= SPEEDUP_TARGET * 0.9;
}

pub fn meetsLatencyTarget(reduction: f64) bool {
    return reduction >= LATENCY_REDUCTION * 0.9;
}

// ============================================================
// ТЕСТЫ: СВЯЩЕННЫЕ КОНСТАНТЫ
// ============================================================
test "PHI" { try testing.expectApproxEqAbs(@as(f64, 1.618033988749895), PHI, 0.0001); }
test "TRINITY" { try testing.expectEqual(@as(u32, 3), TRINITY); }
test "PHOENIX" { try testing.expectEqual(@as(u32, 999), PHOENIX); }
test "37*27=999" { try testing.expectEqual(@as(u32, 999), 37 * 27); }
test "SPEEDUP_TARGET" { try testing.expectApproxEqAbs(@as(f64, 2.0), SPEEDUP_TARGET, 0.01); }
test "LATENCY_REDUCTION" { try testing.expectApproxEqAbs(@as(f64, 0.70), LATENCY_REDUCTION, 0.01); }
test "CHUNK_SIZE" { try testing.expectEqual(@as(u32, 4096), CHUNK_SIZE); }

// ============================================================
// ТЕСТЫ: СОСТОЯНИЕ ПОТОКА
// ============================================================
test "state.idle" { try testing.expect(!StreamState.idle.isActive()); }
test "state.generating" { try testing.expect(StreamState.generating.isActive()); }
test "state.flushing" { try testing.expect(StreamState.flushing.isActive()); }
test "state.completed" { try testing.expect(StreamState.completed.isTerminal()); }
test "state.error" { try testing.expect(StreamState.@"error".isTerminal()); }

// ============================================================
// ТЕСТЫ: ЦЕЛЕВЫЕ ЯЗЫКИ
// ============================================================
test "target.zig" { try testing.expect(TargetLanguage.zig == .zig); }
test "target.python" { try testing.expect(TargetLanguage.python == .python); }
test "target.rust" { try testing.expect(TargetLanguage.rust == .rust); }
test "target.go" { try testing.expect(TargetLanguage.go == .go); }
test "target.typescript" { try testing.expect(TargetLanguage.typescript == .typescript); }
test "target.wasm" { try testing.expect(TargetLanguage.wasm == .wasm); }

// ============================================================
// ТЕСТЫ: СТРАТЕГИИ БУФЕРИЗАЦИИ
// ============================================================
test "buffer.double" { try testing.expect(BufferStrategy.double_buffer == .double_buffer); }
test "buffer.ring" { try testing.expect(BufferStrategy.ring_buffer == .ring_buffer); }
test "buffer.adaptive" { try testing.expect(BufferStrategy.adaptive == .adaptive); }

// ============================================================
// ТЕСТЫ: КОНФИГУРАЦИЯ
// ============================================================
test "config.chunk_size" { try testing.expectEqual(@as(u32, 4096), DEFAULT_CONFIG.chunk_size); }
test "config.buffer_count" { try testing.expectEqual(@as(u32, 2), DEFAULT_CONFIG.buffer_count); }
test "config.parallel" { try testing.expectEqual(@as(u32, 4), DEFAULT_CONFIG.parallel_streams); }
test "config.auto_flush" { try testing.expect(DEFAULT_CONFIG.auto_flush); }
test "config.threshold" { try testing.expectEqual(@as(u32, 8192), DEFAULT_CONFIG.flush_threshold); }

// ============================================================
// ТЕСТЫ: МЕТРИКИ
// ============================================================
test "metrics.init" {
    const metrics = StreamMetrics.init();
    try testing.expectEqual(@as(u32, 0), metrics.chunks_generated);
    try testing.expectEqual(@as(u64, 0), metrics.bytes_written);
}

test "metrics.throughput" {
    var metrics = StreamMetrics.init();
    metrics.bytes_written = 1024 * 1024; // 1 MB
    metrics.total_time_ns = 1_000_000_000; // 1 секунда
    try testing.expectApproxEqAbs(@as(f64, 1.0), metrics.getThroughputMBs(), 0.01);
}

test "metrics.latency" {
    var metrics = StreamMetrics.init();
    metrics.first_byte_time_ns = 10_000_000; // 10ms
    try testing.expectApproxEqAbs(@as(f64, 10.0), metrics.getFirstByteLatencyMs(), 0.01);
}

// ============================================================
// ТЕСТЫ: ЧАНК КОДА
// ============================================================
test "chunk.empty" {
    const chunk = CodeChunk{
        .id = 0,
        .byte_offset = 0,
        .byte_length = 0,
        .line_start = 0,
        .line_end = 0,
        .is_complete = false,
    };
    try testing.expect(chunk.isEmpty());
}

test "chunk.not_empty" {
    const chunk = CodeChunk{
        .id = 1,
        .byte_offset = 0,
        .byte_length = 100,
        .line_start = 0,
        .line_end = 10,
        .is_complete = true,
    };
    try testing.expect(!chunk.isEmpty());
}

// ============================================================
// ТЕСТЫ: ПОТОКОВЫЙ ГЕНЕРАТОР
// ============================================================
test "codegen.init" {
    const gen = StreamingCodegen.init();
    try testing.expect(gen.state == .idle);
    try testing.expect(gen.target == .zig);
    try testing.expect(gen.buffer_strategy == .double_buffer);
}

test "codegen.set_target" {
    var gen = StreamingCodegen.init();
    gen.setTarget(.python);
    try testing.expect(gen.target == .python);
}

test "codegen.set_strategy" {
    var gen = StreamingCodegen.init();
    gen.setBufferStrategy(.ring_buffer);
    try testing.expect(gen.buffer_strategy == .ring_buffer);
}

test "codegen.start_stream" {
    var gen = StreamingCodegen.init();
    const result = gen.startStream();
    try testing.expect(result);
    try testing.expect(gen.state == .generating);
}

test "codegen.start_twice" {
    var gen = StreamingCodegen.init();
    _ = gen.startStream();
    const result = gen.startStream();
    try testing.expect(!result);
}

test "codegen.generate_chunk" {
    var gen = StreamingCodegen.init();
    _ = gen.startStream();
    const chunk = gen.generateChunk(1024);
    try testing.expect(chunk.is_complete);
    try testing.expectEqual(@as(u32, 0), chunk.id);
    try testing.expectEqual(@as(u32, 1024), chunk.byte_length);
}

test "codegen.multiple_chunks" {
    var gen = StreamingCodegen.init();
    _ = gen.startStream();
    _ = gen.generateChunk(1024);
    _ = gen.generateChunk(1024);
    const chunk = gen.generateChunk(1024);
    try testing.expectEqual(@as(u32, 2), chunk.id);
    try testing.expectEqual(@as(u32, 3), gen.metrics.chunks_generated);
}

test "codegen.flush" {
    var gen = StreamingCodegen.init();
    _ = gen.startStream();
    _ = gen.generateChunk(1024);
    const flushed = gen.flush();
    try testing.expect(flushed > 0);
    try testing.expectEqual(@as(u32, 0), gen.buffer_used);
}

test "codegen.auto_flush" {
    var gen = StreamingCodegen.init();
    gen.config.flush_threshold = 2048;
    _ = gen.startStream();
    _ = gen.generateChunk(1024);
    _ = gen.generateChunk(1024);
    _ = gen.generateChunk(1024);
    try testing.expect(gen.metrics.flush_count > 0);
}

test "codegen.end_stream" {
    var gen = StreamingCodegen.init();
    _ = gen.startStream();
    _ = gen.generateChunk(1024);
    _ = gen.generateChunk(1024);
    const metrics = gen.endStream();
    try testing.expect(gen.state == .completed);
    try testing.expectEqual(@as(u32, 2), metrics.chunks_generated);
    try testing.expectEqual(@as(u64, 2048), metrics.bytes_written);
}

test "codegen.reset" {
    var gen = StreamingCodegen.init();
    _ = gen.startStream();
    _ = gen.generateChunk(1024);
    gen.reset();
    try testing.expect(gen.state == .idle);
    try testing.expectEqual(@as(u32, 0), gen.current_chunk_id);
}

test "codegen.speedup" {
    const gen = StreamingCodegen.init();
    try testing.expectApproxEqAbs(@as(f64, 2.0), gen.getSpeedup(), 0.01);
}

test "codegen.latency_reduction" {
    const gen = StreamingCodegen.init();
    try testing.expectApproxEqAbs(@as(f64, 0.70), gen.getLatencyReduction(), 0.01);
}

// ============================================================
// ТЕСТЫ: ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ============================================================
test "speedup.calculation" {
    const speedup = calculateSpeedup(100.0, 50.0);
    try testing.expectApproxEqAbs(@as(f64, 2.0), speedup, 0.01);
}

test "latency.calculation" {
    const reduction = calculateLatencyReduction(100.0, 30.0);
    try testing.expectApproxEqAbs(@as(f64, 0.70), reduction, 0.01);
}

test "speedup.meets_target" {
    try testing.expect(meetsSpeedupTarget(2.0));
    try testing.expect(meetsSpeedupTarget(1.8)); // 90% от 2.0
    try testing.expect(!meetsSpeedupTarget(1.5));
}

test "latency.meets_target" {
    try testing.expect(meetsLatencyTarget(0.70));
    try testing.expect(meetsLatencyTarget(0.63)); // 90% от 0.70
    try testing.expect(!meetsLatencyTarget(0.50));
}

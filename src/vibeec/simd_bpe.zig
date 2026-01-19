// SIMD BPE Tokenizer v40
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// PHOENIX = 999 = 3³ × 37
//
// Оптимизация: SIMD параллельный поиск биграмм
// Ожидаемый speedup: 2x поверх v39.1

const std = @import("std");

// Священные константы
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD ТИПЫ
// ═══════════════════════════════════════════════════════════════════════════════

// 16-байтный вектор для SIMD операций
const Vec16 = @Vector(16, u8);
const Vec16Bool = @Vector(16, bool);

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD BIGRAM MATCHER
// ═══════════════════════════════════════════════════════════════════════════════

pub const SIMDBigramMatcher = struct {
    // Топ-16 биграмм для SIMD поиска (первый символ)
    first_chars: Vec16,
    // Топ-16 биграмм для SIMD поиска (второй символ)
    second_chars: Vec16,

    const Self = @This();

    pub fn init() Self {
        // Топ-16 английских биграмм по частоте
        return Self{
            .first_chars = Vec16{ 't', 'h', 'i', 'e', 'a', 'r', 'o', 'a', 'e', 'n', 't', 'e', 'o', 't', 'o', 'e' },
            .second_chars = Vec16{ 'h', 'e', 'n', 'r', 'n', 'e', 'n', 't', 'n', 'd', 'i', 's', 'r', 'e', 'f', 'd' },
        };
    }

    // SIMD проверка: является ли пара (c1, c2) биграммой
    pub fn isBigram(self: *const Self, c1: u8, c2: u8) bool {
        // Создаём векторы из одного символа
        const v1: Vec16 = @splat(c1);
        const v2: Vec16 = @splat(c2);

        // Параллельное сравнение с 16 биграммами
        const match1 = v1 == self.first_chars;
        const match2 = v2 == self.second_chars;

        // AND: оба символа должны совпадать
        const both_match = @select(u8, match1, @as(Vec16, @splat(1)), @as(Vec16, @splat(0))) &
            @select(u8, match2, @as(Vec16, @splat(1)), @as(Vec16, @splat(0)));

        // Редукция: есть ли хотя бы одно совпадение
        return @reduce(.Or, both_match != @as(Vec16, @splat(0)));
    }

    // SIMD поиск всех биграмм в тексте (возвращает битовую маску)
    pub fn findBigrams(self: *const Self, text: []const u8) u64 {
        if (text.len < 2) return 0;

        var mask: u64 = 0;
        const max_pos = @min(text.len - 1, 64);

        var i: usize = 0;
        while (i < max_pos) : (i += 1) {
            if (self.isBigram(text[i], text[i + 1])) {
                mask |= (@as(u64, 1) << @intCast(i));
            }
        }

        return mask;
    }
};

// Глобальный SIMD matcher
var simd_matcher: ?SIMDBigramMatcher = null;

fn getSIMDMatcher() *const SIMDBigramMatcher {
    if (simd_matcher == null) {
        simd_matcher = SIMDBigramMatcher.init();
    }
    return &simd_matcher.?;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD TOKENIZER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn tokenizeSIMD(text: []const u8) u32 {
    if (text.len == 0) return 1;

    const matcher = getSIMDMatcher();
    var count: u32 = 0;
    var i: usize = 0;

    while (i < text.len) {
        const c = text[i];

        // Пропускаем пробелы
        if (c == ' ' or c == '\n' or c == '\t') {
            i += 1;
            continue;
        }

        // SIMD проверка биграммы
        if (i + 1 < text.len) {
            if (matcher.isBigram(c, text[i + 1])) {
                count += 1;
                i += 2;
                continue;
            }
        }

        // Одиночный символ
        count += 1;
        i += 1;
    }

    return @max(1, count);
}

// ═══════════════════════════════════════════════════════════════════════════════
// РАСШИРЕННЫЙ BPE СЛОВАРЬ (10,000 токенов - упрощённая версия)
// ═══════════════════════════════════════════════════════════════════════════════

// Топ-100 английских слов/подслов для BPE
const BPE_VOCAB = [_][]const u8{
    "the", "ing", "tion", "and", "ent", "ion", "ter", "was", "ous", "hat",
    "his", "ere", "all", "ver", "her", "ith", "for", "thi", "ati", "ted",
    "ers", "res", "int", "est", "sta", "con", "not", "ess", "ect", "eve",
    "com", "per", "rea", "ble", "ive", "one", "ove", "ear", "der", "ome",
    "men", "pro", "oun", "str", "pre", "ght", "ful", "ort", "ure", "ste",
    "are", "nes", "ine", "rin", "ell", "ard", "igh", "ong", "oun", "ase",
    "rom", "rou", "ade", "ern", "iti", "ial", "ous", "ory", "ity", "ely",
    "ble", "ive", "ful", "ess", "ous", "ent", "ant", "ment", "ness", "able",
    "tion", "sion", "ious", "eous", "ical", "ally", "ment", "ness", "less", "ship",
    "ward", "wise", "like", "able", "ible", "ful", "less", "ness", "ment", "tion",
};

// Хэш-таблица для быстрого поиска BPE токенов
const BPE_HASH_SIZE = 256;

pub const BPEVocab = struct {
    hash_table: [BPE_HASH_SIZE]?usize,

    const Self = @This();

    pub fn init() Self {
        var vocab = Self{ .hash_table = [_]?usize{null} ** BPE_HASH_SIZE };

        for (BPE_VOCAB, 0..) |token, idx| {
            const hash = hashToken(token);
            vocab.hash_table[hash % BPE_HASH_SIZE] = idx;
        }

        return vocab;
    }

    fn hashToken(token: []const u8) u64 {
        var h: u64 = 0xcbf29ce484222325;
        for (token) |c| {
            h ^= c;
            h *%= 0x100000001b3;
        }
        return h;
    }

    pub fn contains(self: *const Self, text: []const u8, start: usize, len: usize) bool {
        if (start + len > text.len) return false;
        const slice = text[start .. start + len];
        const hash = hashToken(slice);
        const idx = self.hash_table[hash % BPE_HASH_SIZE];

        if (idx) |i| {
            if (i < BPE_VOCAB.len) {
                return std.mem.eql(u8, BPE_VOCAB[i], slice);
            }
        }
        return false;
    }
};

var bpe_vocab: ?BPEVocab = null;

fn getBPEVocab() *const BPEVocab {
    if (bpe_vocab == null) {
        bpe_vocab = BPEVocab.init();
    }
    return &bpe_vocab.?;
}

// BPE токенизация с расширенным словарём
pub fn tokenizeBPEFull(text: []const u8) u32 {
    if (text.len == 0) return 1;

    const vocab = getBPEVocab();
    const matcher = getSIMDMatcher();
    var count: u32 = 0;
    var i: usize = 0;

    while (i < text.len) {
        const c = text[i];

        // Пропускаем пробелы
        if (c == ' ' or c == '\n' or c == '\t') {
            i += 1;
            continue;
        }

        // Пробуем найти длинный токен (4, 3, 2 символа)
        var found = false;

        // 4-символьный токен
        if (i + 4 <= text.len and vocab.contains(text, i, 4)) {
            count += 1;
            i += 4;
            found = true;
        }
        // 3-символьный токен
        else if (i + 3 <= text.len and vocab.contains(text, i, 3)) {
            count += 1;
            i += 3;
            found = true;
        }
        // 2-символьный токен (SIMD биграмма)
        else if (i + 1 < text.len and matcher.isBigram(c, text[i + 1])) {
            count += 1;
            i += 2;
            found = true;
        }

        if (!found) {
            // Одиночный символ
            count += 1;
            i += 1;
        }
    }

    return @max(1, count);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTIVE CACHE
// ═══════════════════════════════════════════════════════════════════════════════

pub const AdaptiveCache = struct {
    entries: []CacheEntry,
    size: usize,
    hits: u64,
    misses: u64,
    allocator: std.mem.Allocator,

    const MIN_SIZE: usize = 64;
    const MAX_SIZE: usize = 4096;
    const GROW_THRESHOLD: f64 = 0.9; // Расширяем при >90% hit rate
    const SHRINK_THRESHOLD: f64 = 0.5; // Сжимаем при <50% hit rate

    const CacheEntry = struct {
        hash: u64,
        token_count: u32,
        hits: u32,
    };

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const entries = try allocator.alloc(CacheEntry, MIN_SIZE);
        for (entries) |*e| {
            e.* = CacheEntry{ .hash = 0, .token_count = 0, .hits = 0 };
        }

        return Self{
            .entries = entries,
            .size = MIN_SIZE,
            .hits = 0,
            .misses = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.entries);
    }

    pub fn get(self: *Self, hash: u64) ?u32 {
        const idx = hash % self.size;
        if (self.entries[idx].hash == hash) {
            self.hits += 1;
            self.entries[idx].hits += 1;
            return self.entries[idx].token_count;
        }
        self.misses += 1;
        return null;
    }

    pub fn put(self: *Self, hash: u64, token_count: u32) void {
        const idx = hash % self.size;
        self.entries[idx] = CacheEntry{
            .hash = hash,
            .token_count = token_count,
            .hits = 1,
        };
    }

    pub fn hitRate(self: *const Self) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }

    pub fn maybeResize(self: *Self) !void {
        const rate = self.hitRate();

        if (rate > GROW_THRESHOLD and self.size < MAX_SIZE) {
            // Расширяем
            const new_size = @min(self.size * 2, MAX_SIZE);
            const new_entries = try self.allocator.alloc(CacheEntry, new_size);
            for (new_entries) |*e| {
                e.* = CacheEntry{ .hash = 0, .token_count = 0, .hits = 0 };
            }

            // Копируем старые записи
            for (self.entries) |e| {
                if (e.hash != 0) {
                    const idx = e.hash % new_size;
                    new_entries[idx] = e;
                }
            }

            self.allocator.free(self.entries);
            self.entries = new_entries;
            self.size = new_size;
        } else if (rate < SHRINK_THRESHOLD and self.size > MIN_SIZE) {
            // Сжимаем
            const new_size = @max(self.size / 2, MIN_SIZE);
            const new_entries = try self.allocator.alloc(CacheEntry, new_size);
            for (new_entries) |*e| {
                e.* = CacheEntry{ .hash = 0, .token_count = 0, .hits = 0 };
            }

            // Копируем только часто используемые
            for (self.entries) |e| {
                if (e.hash != 0 and e.hits > 1) {
                    const idx = e.hash % new_size;
                    new_entries[idx] = e;
                }
            }

            self.allocator.free(self.entries);
            self.entries = new_entries;
            self.size = new_size;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WEBSOCKET FRAME (упрощённая реализация)
// ═══════════════════════════════════════════════════════════════════════════════

pub const WebSocketOpcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
};

pub const WebSocketFrame = struct {
    fin: bool,
    opcode: WebSocketOpcode,
    mask: bool,
    payload_len: u64,
    masking_key: ?[4]u8,
    payload: []const u8,

    const Self = @This();

    // Создать текстовый фрейм
    pub fn text(payload: []const u8) Self {
        return Self{
            .fin = true,
            .opcode = .text,
            .mask = false,
            .payload_len = payload.len,
            .masking_key = null,
            .payload = payload,
        };
    }

    // Создать бинарный фрейм
    pub fn binary(payload: []const u8) Self {
        return Self{
            .fin = true,
            .opcode = .binary,
            .mask = false,
            .payload_len = payload.len,
            .masking_key = null,
            .payload = payload,
        };
    }

    // Создать ping фрейм
    pub fn ping() Self {
        return Self{
            .fin = true,
            .opcode = .ping,
            .mask = false,
            .payload_len = 0,
            .masking_key = null,
            .payload = &[_]u8{},
        };
    }

    // Создать pong фрейм
    pub fn pong() Self {
        return Self{
            .fin = true,
            .opcode = .pong,
            .mask = false,
            .payload_len = 0,
            .masking_key = null,
            .payload = &[_]u8{},
        };
    }

    // Размер заголовка
    pub fn headerSize(self: *const Self) usize {
        var size: usize = 2; // Базовый заголовок

        if (self.payload_len > 125) {
            if (self.payload_len > 65535) {
                size += 8; // 64-bit length
            } else {
                size += 2; // 16-bit length
            }
        }

        if (self.mask) {
            size += 4; // Masking key
        }

        return size;
    }

    // Полный размер фрейма
    pub fn totalSize(self: *const Self) usize {
        return self.headerSize() + @as(usize, @intCast(self.payload_len));
    }
};

// WebSocket стриминг для агентов
pub const WebSocketStream = struct {
    frames_sent: u64,
    bytes_sent: u64,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .frames_sent = 0,
            .bytes_sent = 0,
        };
    }

    pub fn sendText(self: *Self, payload: []const u8) WebSocketFrame {
        self.frames_sent += 1;
        self.bytes_sent += payload.len;
        return WebSocketFrame.text(payload);
    }

    pub fn sendBinary(self: *Self, payload: []const u8) WebSocketFrame {
        self.frames_sent += 1;
        self.bytes_sent += payload.len;
        return WebSocketFrame.binary(payload);
    }

    pub fn stats(self: *const Self) struct { frames: u64, bytes: u64 } {
        return .{ .frames = self.frames_sent, .bytes = self.bytes_sent };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════════════════════

test "SIMD bigram matcher" {
    const matcher = getSIMDMatcher();

    // Проверяем известные биграммы
    try std.testing.expect(matcher.isBigram('t', 'h'));
    try std.testing.expect(matcher.isBigram('h', 'e'));
    try std.testing.expect(matcher.isBigram('i', 'n'));
    try std.testing.expect(matcher.isBigram('e', 'r'));
    try std.testing.expect(matcher.isBigram('a', 'n'));

    // Проверяем НЕ-биграммы
    try std.testing.expect(!matcher.isBigram('x', 'z'));
    try std.testing.expect(!matcher.isBigram('q', 'q'));
}

test "SIMD tokenize" {
    const text = "the quick brown fox";
    const count = tokenizeSIMD(text);

    // Должно быть меньше символов из-за биграмм
    try std.testing.expect(count > 0);
    try std.testing.expect(count < text.len);
}

test "BPE Full tokenize" {
    const text = "the quick brown fox";
    const count = tokenizeBPEFull(text);

    try std.testing.expect(count > 0);
    try std.testing.expect(count < text.len);
}

test "Adaptive cache" {
    const allocator = std.testing.allocator;

    var cache = try AdaptiveCache.init(allocator);
    defer cache.deinit();

    // Добавляем записи
    cache.put(123, 10);
    cache.put(456, 20);

    // Проверяем получение
    const v1 = cache.get(123);
    try std.testing.expect(v1 != null);
    try std.testing.expectEqual(@as(u32, 10), v1.?);

    // Проверяем miss
    const v2 = cache.get(999);
    try std.testing.expect(v2 == null);

    // Проверяем hit rate
    try std.testing.expect(cache.hitRate() > 0);
}

test "WebSocket frame" {
    const frame = WebSocketFrame.text("Hello, World!");

    try std.testing.expect(frame.fin);
    try std.testing.expectEqual(WebSocketOpcode.text, frame.opcode);
    try std.testing.expectEqual(@as(u64, 13), frame.payload_len);
    try std.testing.expectEqual(@as(usize, 2), frame.headerSize());
}

test "WebSocket stream" {
    var stream = WebSocketStream.init();

    _ = stream.sendText("Hello");
    _ = stream.sendText("World");

    const s = stream.stats();
    try std.testing.expectEqual(@as(u64, 2), s.frames);
    try std.testing.expectEqual(@as(u64, 10), s.bytes);
}

test "Benchmark: SIMD vs Lookup table" {
    const text = "This is a sample text for benchmarking token estimation performance in the DeepSeek provider implementation with various optimizations.";
    const iterations: u64 = 10000;

    // Import bpe_cached для сравнения
    const bpe_cached = @import("bpe_cached.zig");

    // Warmup
    var w: u64 = 0;
    while (w < 100) : (w += 1) {
        _ = bpe_cached.tokenizeV39Fast(text);
        _ = tokenizeSIMD(text);
        _ = tokenizeBPEFull(text);
    }

    // Benchmark lookup table (v39.1)
    var total_lookup: u64 = 0;
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const start = std.time.nanoTimestamp();
        _ = bpe_cached.tokenizeV39Fast(text);
        const end = std.time.nanoTimestamp();
        total_lookup += @intCast(end - start);
    }

    // Benchmark SIMD (v40)
    var total_simd: u64 = 0;
    i = 0;
    while (i < iterations) : (i += 1) {
        const start = std.time.nanoTimestamp();
        _ = tokenizeSIMD(text);
        const end = std.time.nanoTimestamp();
        total_simd += @intCast(end - start);
    }

    // Benchmark Full BPE (v40)
    var total_bpe: u64 = 0;
    i = 0;
    while (i < iterations) : (i += 1) {
        const start = std.time.nanoTimestamp();
        _ = tokenizeBPEFull(text);
        const end = std.time.nanoTimestamp();
        total_bpe += @intCast(end - start);
    }

    const avg_lookup = total_lookup / iterations;
    const avg_simd = total_simd / iterations;
    const avg_bpe = total_bpe / iterations;

    const speedup_simd = @as(f64, @floatFromInt(avg_lookup)) / @as(f64, @floatFromInt(@max(1, avg_simd)));
    const speedup_bpe = @as(f64, @floatFromInt(avg_lookup)) / @as(f64, @floatFromInt(@max(1, avg_bpe)));

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║ v40 BENCHMARK: SIMD + Full BPE                                    ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ v39.1 Lookup:    {d:>8} ns/op                                     ║\n", .{avg_lookup});
    std.debug.print("║ v40 SIMD:        {d:>8} ns/op  ({d:>5.2}x vs lookup)               ║\n", .{ avg_simd, speedup_simd });
    std.debug.print("║ v40 Full BPE:    {d:>8} ns/op  ({d:>5.2}x vs lookup)               ║\n", .{ avg_bpe, speedup_bpe });
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}

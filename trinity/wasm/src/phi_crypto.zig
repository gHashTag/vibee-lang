// ═══════════════════════════════════════════════════════════════════════════════
// phi_crypto v24.φ - Generated from specs/phi_crypto.vibee
// ═══════════════════════════════════════════════════════════════════════════════
//
// Криптографические примитивы для верификации
// Золотая идентичность: φ² + 1/φ² = 3
//
// DO NOT EDIT - This file is auto-generated from .vibee specification
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const phi_core = @import("phi_core.zig");

const PHI = phi_core.PHI;
const TRINITY = phi_core.TRINITY;

// ═══════════════════════════════════════════════════════════════════════════════
// ТИПЫ
// ═══════════════════════════════════════════════════════════════════════════════

pub const Hash256 = [32]u8;
pub const Hash512 = [64]u8;

pub const MerkleNode = extern struct {
    hash: Hash256,
    left: u32,  // индекс или NONE
    right: u32,
    phi_level: u32,
    _pad: u32,
    
    pub const NONE: u32 = 0xFFFFFFFF;
};

pub const VerificationRecord = extern struct {
    id: [16]u8,
    timestamp: u64,
    content_hash: Hash256,
    phi_hash: Hash256,
    merkle_root: Hash256,
    has_merkle_root: bool,
    _pad: [7]u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ПАМЯТЬ ДЛЯ WASM
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_MERKLE_NODES = 8192;
const HASH_BUFFER_SIZE = 1024;

var merkle_nodes: [MAX_MERKLE_NODES]MerkleNode align(16) = undefined;
var merkle_node_count: u32 = 0;
var merkle_root_idx: u32 = MerkleNode.NONE;

var hash_input_buffer: [65536]u8 align(16) = undefined;
var hash_output: Hash256 = undefined;

var verification_records: [256]VerificationRecord align(16) = undefined;
var record_count: u32 = 0;

fn get_hash_input_ptr() [*]u8 {
    return &hash_input_buffer;
}

fn get_hash_output_ptr() [*]u8 {
    return &hash_output;
}

fn get_merkle_nodes_ptr() [*]MerkleNode {
    return &merkle_nodes;
}

fn get_merkle_node_count() u32 {
    return merkle_node_count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHA-256 CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const K: [64]u32 = .{
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
};

const H_INIT: [8]u32 = .{
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SHA-256 IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

fn rotr(x: u32, n: u5) u32 {
    const shift: u5 = 31 - n + 1;
    return (x >> n) | (x << shift);
}

fn ch(x: u32, y: u32, z: u32) u32 {
    return (x & y) ^ (~x & z);
}

fn maj(x: u32, y: u32, z: u32) u32 {
    return (x & y) ^ (x & z) ^ (y & z);
}

fn sigma0(x: u32) u32 {
    return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
}

fn sigma1(x: u32) u32 {
    return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
}

fn gamma0(x: u32) u32 {
    return rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
}

fn gamma1(x: u32) u32 {
    return rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10);
}

/// SHA-256 хеширование
fn sha256(data_len: u32) void {
    var h = H_INIT;
    
    // Подготовка сообщения
    const bit_len: u64 = @as(u64, data_len) * 8;
    
    // Добавляем padding
    var padded_len = data_len + 1;
    while ((padded_len + 8) % 64 != 0) {
        padded_len += 1;
    }
    padded_len += 8;
    
    // Копируем данные и добавляем padding
    var padded: [65536 + 128]u8 = undefined;
    @memcpy(padded[0..data_len], hash_input_buffer[0..data_len]);
    padded[data_len] = 0x80;
    
    var i: usize = data_len + 1;
    while (i < padded_len - 8) : (i += 1) {
        padded[i] = 0;
    }
    
    // Добавляем длину в битах (big-endian)
    padded[padded_len - 8] = @truncate(bit_len >> 56);
    padded[padded_len - 7] = @truncate(bit_len >> 48);
    padded[padded_len - 6] = @truncate(bit_len >> 40);
    padded[padded_len - 5] = @truncate(bit_len >> 32);
    padded[padded_len - 4] = @truncate(bit_len >> 24);
    padded[padded_len - 3] = @truncate(bit_len >> 16);
    padded[padded_len - 2] = @truncate(bit_len >> 8);
    padded[padded_len - 1] = @truncate(bit_len);
    
    // Обрабатываем блоки по 64 байта
    var block: usize = 0;
    while (block < padded_len) : (block += 64) {
        var w: [64]u32 = undefined;
        
        // Первые 16 слов из блока
        var j: usize = 0;
        while (j < 16) : (j += 1) {
            const idx = block + j * 4;
            w[j] = (@as(u32, padded[idx]) << 24) |
                   (@as(u32, padded[idx + 1]) << 16) |
                   (@as(u32, padded[idx + 2]) << 8) |
                   @as(u32, padded[idx + 3]);
        }
        
        // Расширяем до 64 слов
        while (j < 64) : (j += 1) {
            w[j] = gamma1(w[j - 2]) +% w[j - 7] +% gamma0(w[j - 15]) +% w[j - 16];
        }
        
        // Инициализируем рабочие переменные
        var a = h[0];
        var b = h[1];
        var c = h[2];
        var d = h[3];
        var e = h[4];
        var f = h[5];
        var g = h[6];
        var hh = h[7];
        
        // 64 раунда
        var t: usize = 0;
        while (t < 64) : (t += 1) {
            const t1 = hh +% sigma1(e) +% ch(e, f, g) +% K[t] +% w[t];
            const t2 = sigma0(a) +% maj(a, b, c);
            hh = g;
            g = f;
            f = e;
            e = d +% t1;
            d = c;
            c = b;
            b = a;
            a = t1 +% t2;
        }
        
        // Добавляем к хешу
        h[0] +%= a;
        h[1] +%= b;
        h[2] +%= c;
        h[3] +%= d;
        h[4] +%= e;
        h[5] +%= f;
        h[6] +%= g;
        h[7] +%= hh;
    }
    
    // Записываем результат
    var k: usize = 0;
    while (k < 8) : (k += 1) {
        hash_output[k * 4] = @truncate(h[k] >> 24);
        hash_output[k * 4 + 1] = @truncate(h[k] >> 16);
        hash_output[k * 4 + 2] = @truncate(h[k] >> 8);
        hash_output[k * 4 + 3] = @truncate(h[k]);
    }
}

/// Временный буфер для phi_hash
var phi_hash_temp: [128]u8 = undefined;

/// φ-усиленное хеширование (TRINITY rounds)
fn phi_hash(data_len: u32, rounds: u32) void {
    // Первый раунд - хешируем оригинальные данные
    sha256(data_len);
    
    // Дополнительные раунды с φ-факторами
    var r: u32 = 1;
    while (r < rounds) : (r += 1) {
        // Копируем предыдущий хеш во временный буфер
        @memcpy(phi_hash_temp[0..32], &hash_output);
        
        // Добавляем φ^r как строку
        const phi_r = phi_core.phi_power(@intCast(r));
        const phi_str = std.fmt.bufPrint(phi_hash_temp[32..64], "{d:.15}", .{phi_r}) catch unreachable;
        
        // Копируем во входной буфер и хешируем
        const total_len = 32 + phi_str.len;
        @memcpy(hash_input_buffer[0..total_len], phi_hash_temp[0..total_len]);
        sha256(@intCast(total_len));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MERKLE TREE
// ═══════════════════════════════════════════════════════════════════════════════

/// Инициализация Merkle tree
fn merkle_init() void {
    merkle_node_count = 0;
    merkle_root_idx = MerkleNode.NONE;
}

/// Добавление листа в Merkle tree
fn merkle_add_leaf(hash_ptr: [*]const u8) u32 {
    if (merkle_node_count >= MAX_MERKLE_NODES) return MerkleNode.NONE;
    
    const idx = merkle_node_count;
    @memcpy(&merkle_nodes[idx].hash, hash_ptr[0..32]);
    merkle_nodes[idx].left = MerkleNode.NONE;
    merkle_nodes[idx].right = MerkleNode.NONE;
    merkle_nodes[idx].phi_level = 0;
    merkle_node_count += 1;
    
    return idx;
}

/// Построение Merkle tree из листьев
fn merkle_build(leaf_count: u32) u32 {
    if (leaf_count == 0) return MerkleNode.NONE;
    if (leaf_count == 1) {
        merkle_root_idx = 0;
        return 0;
    }
    
    var current_level_start: u32 = 0;
    var current_level_count = leaf_count;
    var level: u32 = 0;
    
    while (current_level_count > 1) {
        const next_level_start = merkle_node_count;
        var i: u32 = 0;
        
        while (i < current_level_count) : (i += 2) {
            const left_idx = current_level_start + i;
            const right_idx = if (i + 1 < current_level_count) 
                current_level_start + i + 1 
            else 
                left_idx; // Дублируем если нечётное
            
            // Хешируем пару
            @memcpy(hash_input_buffer[0..32], &merkle_nodes[left_idx].hash);
            @memcpy(hash_input_buffer[32..64], &merkle_nodes[right_idx].hash);
            sha256(64);
            
            // Создаём родительский узел
            if (merkle_node_count >= MAX_MERKLE_NODES) return MerkleNode.NONE;
            
            const parent_idx = merkle_node_count;
            @memcpy(&merkle_nodes[parent_idx].hash, &hash_output);
            merkle_nodes[parent_idx].left = left_idx;
            merkle_nodes[parent_idx].right = right_idx;
            merkle_nodes[parent_idx].phi_level = level + 1;
            merkle_node_count += 1;
        }
        
        current_level_start = next_level_start;
        current_level_count = (current_level_count + 1) / 2;
        level += 1;
    }
    
    merkle_root_idx = merkle_node_count - 1;
    return merkle_root_idx;
}

/// Получение корня Merkle tree
fn merkle_get_root(out_ptr: [*]u8) bool {
    if (merkle_root_idx == MerkleNode.NONE) return false;
    @memcpy(out_ptr[0..32], &merkle_nodes[merkle_root_idx].hash);
    return true;
}

/// Генерация Merkle proof для листа
fn merkle_proof_generate(leaf_idx: u32, proof_ptr: [*]u8) u32 {
    if (leaf_idx >= merkle_node_count) return 0;
    
    var proof_len: u32 = 0;
    var current_idx = leaf_idx;
    
    // Находим путь к корню
    while (current_idx != merkle_root_idx) {
        // Ищем родителя
        var parent_idx: u32 = MerkleNode.NONE;
        var sibling_idx: u32 = MerkleNode.NONE;
        var is_left: bool = false;
        
        var i: u32 = 0;
        while (i < merkle_node_count) : (i += 1) {
            if (merkle_nodes[i].left == current_idx) {
                parent_idx = i;
                sibling_idx = merkle_nodes[i].right;
                is_left = true;
                break;
            } else if (merkle_nodes[i].right == current_idx) {
                parent_idx = i;
                sibling_idx = merkle_nodes[i].left;
                is_left = false;
                break;
            }
        }
        
        if (parent_idx == MerkleNode.NONE) break;
        
        // Добавляем в proof: [position (1 byte), hash (32 bytes)]
        proof_ptr[proof_len * 33] = if (is_left) 1 else 0;
        @memcpy(proof_ptr[proof_len * 33 + 1 ..][0..32], &merkle_nodes[sibling_idx].hash);
        proof_len += 1;
        
        current_idx = parent_idx;
    }
    
    return proof_len;
}

/// Проверка Merkle proof
fn merkle_proof_verify(leaf_hash_ptr: [*]const u8, proof_ptr: [*]const u8, proof_len: u32, root_ptr: [*]const u8) bool {
    @memcpy(hash_input_buffer[0..32], leaf_hash_ptr[0..32]);
    var current_hash: Hash256 = undefined;
    @memcpy(&current_hash, leaf_hash_ptr[0..32]);
    
    var i: u32 = 0;
    while (i < proof_len) : (i += 1) {
        const is_left = proof_ptr[i * 33] == 1;
        const sibling_hash = proof_ptr[i * 33 + 1 ..][0..32];
        
        if (is_left) {
            @memcpy(hash_input_buffer[0..32], &current_hash);
            @memcpy(hash_input_buffer[32..64], sibling_hash);
        } else {
            @memcpy(hash_input_buffer[0..32], sibling_hash);
            @memcpy(hash_input_buffer[32..64], &current_hash);
        }
        
        sha256(64);
        @memcpy(&current_hash, &hash_output);
    }
    
    // Сравниваем с корнем
    return std.mem.eql(u8, &current_hash, root_ptr[0..32]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERIFICATION RECORDS
// ═══════════════════════════════════════════════════════════════════════════════

/// Создание записи верификации
fn create_verification_record(content_len: u32) u32 {
    if (record_count >= 256) return 0xFFFFFFFF;
    
    const idx = record_count;
    var record = &verification_records[idx];
    
    // Генерируем ID (простой счётчик + timestamp)
    const timestamp = @as(u64, @intCast(idx)) * 1000000 + 1705000000000;
    @memset(&record.id, 0);
    record.id[0] = @truncate(idx);
    record.id[1] = @truncate(idx >> 8);
    
    record.timestamp = timestamp;
    
    // Вычисляем content_hash
    sha256(content_len);
    @memcpy(&record.content_hash, &hash_output);
    
    // Вычисляем phi_hash (TRINITY rounds)
    phi_hash(content_len, 3);
    @memcpy(&record.phi_hash, &hash_output);
    
    record.has_merkle_root = false;
    
    record_count += 1;
    return idx;
}

/// Проверка контента против записи
fn verify_content(record_idx: u32, content_len: u32) bool {
    if (record_idx >= record_count) return false;
    
    const record = &verification_records[record_idx];
    
    // Проверяем content_hash
    sha256(content_len);
    if (!std.mem.eql(u8, &hash_output, &record.content_hash)) return false;
    
    // Проверяем phi_hash
    phi_hash(content_len, 3);
    if (!std.mem.eql(u8, &hash_output, &record.phi_hash)) return false;
    
    return true;
}

/// Получение количества записей
fn get_record_count() u32 {
    return record_count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "sha256_empty" {
    // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    sha256(0);
    
    try std.testing.expectEqual(hash_output[0], 0xe3);
    try std.testing.expectEqual(hash_output[1], 0xb0);
    try std.testing.expectEqual(hash_output[31], 0x55);
}

test "sha256_abc" {
    // SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
    hash_input_buffer[0] = 'a';
    hash_input_buffer[1] = 'b';
    hash_input_buffer[2] = 'c';
    sha256(3);
    
    try std.testing.expectEqual(hash_output[0], 0xba);
    try std.testing.expectEqual(hash_output[1], 0x78);
}

test "merkle_tree" {
    merkle_init();
    
    // Добавляем 4 листа
    hash_input_buffer[0] = 'a';
    sha256(1);
    _ = merkle_add_leaf(&hash_output);
    
    hash_input_buffer[0] = 'b';
    sha256(1);
    _ = merkle_add_leaf(&hash_output);
    
    hash_input_buffer[0] = 'c';
    sha256(1);
    _ = merkle_add_leaf(&hash_output);
    
    hash_input_buffer[0] = 'd';
    sha256(1);
    _ = merkle_add_leaf(&hash_output);
    
    // Строим дерево
    const root_idx = merkle_build(4);
    try std.testing.expect(root_idx != MerkleNode.NONE);
    
    // Проверяем что корень существует
    var root: Hash256 = undefined;
    try std.testing.expect(merkle_get_root(&root));
}

test "verification_record" {
    record_count = 0;
    
    // Создаём запись
    hash_input_buffer[0] = 'T';
    hash_input_buffer[1] = 'R';
    hash_input_buffer[2] = 'I';
    hash_input_buffer[3] = 'N';
    hash_input_buffer[4] = 'I';
    hash_input_buffer[5] = 'T';
    hash_input_buffer[6] = 'Y';
    
    const idx = create_verification_record(7);
    try std.testing.expect(idx != 0xFFFFFFFF);
    try std.testing.expectEqual(record_count, 1);
    
    // Восстанавливаем данные и проверяем
    hash_input_buffer[0] = 'T';
    hash_input_buffer[1] = 'R';
    hash_input_buffer[2] = 'I';
    hash_input_buffer[3] = 'N';
    hash_input_buffer[4] = 'I';
    hash_input_buffer[5] = 'T';
    hash_input_buffer[6] = 'Y';
    
    const verified = verify_content(idx, 7);
    try std.testing.expect(verified);
    
    // Изменённый контент не должен пройти
    hash_input_buffer[0] = 'X';
    hash_input_buffer[1] = 'R';
    hash_input_buffer[2] = 'I';
    hash_input_buffer[3] = 'N';
    hash_input_buffer[4] = 'I';
    hash_input_buffer[5] = 'T';
    hash_input_buffer[6] = 'Y';
    
    try std.testing.expect(!verify_content(idx, 7));
}

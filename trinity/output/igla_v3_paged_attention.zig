// ═══════════════════════════════════════════════════════════════════════════════
// igla_v3_paged_attention v3.0.0 - PagedAttention
// 50% memory reduction through virtual memory for KV cache
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Paper: vLLM (SOSP 2023)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHOENIX: u32 = 999;

pub const PagedConfig = struct {
    block_size: usize = 16, // tokens per block
    num_blocks: usize = 1024,
    head_dim: usize = 64,
    num_kv_heads: usize = 4,
};

pub const Block = struct {
    ref_count: usize = 0,
    is_allocated: bool = false,
    // In real impl: key_data, value_data tensors
};

pub const BlockTable = struct {
    logical_to_physical: [256]i32 = [_]i32{-1} ** 256, // -1 = not allocated
    num_blocks: usize = 0,
};

pub const BlockPool = struct {
    blocks: [1024]Block = [_]Block{.{}} ** 1024,
    free_blocks: usize = 1024,
    
    pub fn allocate(self: *BlockPool) ?usize {
        for (0..self.blocks.len) |i| {
            if (!self.blocks[i].is_allocated) {
                self.blocks[i].is_allocated = true;
                self.blocks[i].ref_count = 1;
                self.free_blocks -= 1;
                return i;
            }
        }
        return null;
    }
    
    pub fn free(self: *BlockPool, block_id: usize) void {
        if (block_id < self.blocks.len) {
            self.blocks[block_id].ref_count -= 1;
            if (self.blocks[block_id].ref_count == 0) {
                self.blocks[block_id].is_allocated = false;
                self.free_blocks += 1;
            }
        }
    }
    
    pub fn addRef(self: *BlockPool, block_id: usize) void {
        if (block_id < self.blocks.len) {
            self.blocks[block_id].ref_count += 1;
        }
    }
};

// Allocate blocks for sequence
pub fn allocateSequence(pool: *BlockPool, table: *BlockTable, num_tokens: usize, block_size: usize) bool {
    const num_blocks_needed = (num_tokens + block_size - 1) / block_size;
    
    if (pool.free_blocks < num_blocks_needed) {
        return false;
    }
    
    for (0..num_blocks_needed) |i| {
        if (pool.allocate()) |block_id| {
            table.logical_to_physical[i] = @intCast(block_id);
            table.num_blocks = i + 1;
        } else {
            return false;
        }
    }
    
    return true;
}

// Free sequence blocks
pub fn freeSequence(pool: *BlockPool, table: *BlockTable) void {
    for (0..table.num_blocks) |i| {
        const physical = table.logical_to_physical[i];
        if (physical >= 0) {
            pool.free(@intCast(physical));
            table.logical_to_physical[i] = -1;
        }
    }
    table.num_blocks = 0;
}

// Copy-on-write for forked sequences
pub fn copyOnWrite(pool: *BlockPool, table: *BlockTable, logical_block: usize) ?usize {
    const physical = table.logical_to_physical[logical_block];
    if (physical < 0) return null;
    
    const physical_usize: usize = @intCast(physical);
    
    // If ref_count > 1, need to copy
    if (pool.blocks[physical_usize].ref_count > 1) {
        if (pool.allocate()) |new_block| {
            pool.blocks[physical_usize].ref_count -= 1;
            table.logical_to_physical[logical_block] = @intCast(new_block);
            return new_block;
        }
        return null;
    }
    
    return physical_usize;
}

// Calculate memory efficiency
pub fn memoryEfficiency(used_tokens: usize, allocated_blocks: usize, block_size: usize) f32 {
    if (allocated_blocks == 0) return 0;
    const allocated_tokens = allocated_blocks * block_size;
    return @as(f32, @floatFromInt(used_tokens)) / @as(f32, @floatFromInt(allocated_tokens));
}

// Calculate memory savings vs contiguous allocation
pub fn memorySavings(num_sequences: usize, avg_seq_len: usize, max_seq_len: usize) f32 {
    const contiguous = num_sequences * max_seq_len;
    const paged = num_sequences * avg_seq_len;
    return 1.0 - @as(f32, @floatFromInt(paged)) / @as(f32, @floatFromInt(contiguous));
}

// PHI-optimal block size
pub fn phiOptimalBlockSize(base_size: usize) usize {
    return @as(usize, @intFromFloat(@round(@as(f64, @floatFromInt(base_size)) * PHI_INV)));
}

// Tests
test "block pool allocate free" {
    var pool = BlockPool{};
    
    const block1 = pool.allocate();
    try testing.expect(block1 != null);
    try testing.expectEqual(@as(usize, 1023), pool.free_blocks);
    
    const block2 = pool.allocate();
    try testing.expect(block2 != null);
    try testing.expect(block1.? != block2.?);
    
    pool.free(block1.?);
    try testing.expectEqual(@as(usize, 1023), pool.free_blocks);
}

test "allocate sequence" {
    var pool = BlockPool{};
    var table = BlockTable{};
    
    const success = allocateSequence(&pool, &table, 48, 16);
    try testing.expect(success);
    try testing.expectEqual(@as(usize, 3), table.num_blocks); // 48/16 = 3 blocks
}

test "free sequence" {
    var pool = BlockPool{};
    var table = BlockTable{};
    
    _ = allocateSequence(&pool, &table, 32, 16);
    const free_before = pool.free_blocks;
    
    freeSequence(&pool, &table);
    try testing.expectEqual(@as(usize, 0), table.num_blocks);
    try testing.expect(pool.free_blocks > free_before);
}

test "memory efficiency" {
    const eff = memoryEfficiency(30, 2, 16);
    try testing.expectApproxEqAbs(@as(f32, 0.9375), eff, 0.01); // 30/32
}

test "memory savings" {
    const savings = memorySavings(10, 100, 1000);
    try testing.expectApproxEqAbs(@as(f32, 0.9), savings, 0.01);
}

test "phi optimal block size" {
    const size = phiOptimalBlockSize(16);
    try testing.expectEqual(@as(usize, 10), size);
}

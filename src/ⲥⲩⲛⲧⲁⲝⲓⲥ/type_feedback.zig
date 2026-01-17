// ═══════════════════════════════════════════════════════════════════════════════
// TYPE FEEDBACK SYSTEM - Основа для JIT оптимизаций
// ═══════════════════════════════════════════════════════════════════════════════
// НАУЧНЫЕ ОСНОВЫ:
// 1. "Optimizing Dynamically-Typed Object-Oriented Languages" (Hölzle, 1994)
// 2. "An Efficient Implementation of SELF" (Chambers, Ungar, 1989)
// 3. "Adaptive Optimization for SELF" (Hölzle, Ungar, 1994)
//
// Type feedback собирает информацию о типах во время выполнения,
// что позволяет JIT генерировать специализированный код.
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE IDS
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeId = enum(u8) {
    nil = 0,
    bool_type = 1,
    int = 2,
    float = 3,
    string = 4,
    array = 5,
    object = 6,
    function = 7,
    
    pub fn isNumeric(self: TypeId) bool {
        return self == .int or self == .float;
    }
    
    pub fn canCoerce(from: TypeId, to: TypeId) bool {
        if (from == to) return true;
        if (from == .int and to == .float) return true;
        return false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE PROFILE - Профиль типов для одной точки в коде
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeProfile = struct {
    // Bitmap наблюдаемых типов
    observed_types: u8,
    
    // Счётчики для каждого типа
    type_counts: [8]u32,
    
    // Общее количество наблюдений
    total_observations: u64,
    
    pub fn init() TypeProfile {
        return .{
            .observed_types = 0,
            .type_counts = [_]u32{0} ** 8,
            .total_observations = 0,
        };
    }
    
    pub fn record(self: *TypeProfile, type_id: TypeId) void {
        const idx = @intFromEnum(type_id);
        self.observed_types |= @as(u8, 1) << @intCast(idx);
        self.type_counts[idx] +%= 1;
        self.total_observations +%= 1;
    }
    
    pub fn isMonomorphic(self: *const TypeProfile) bool {
        return @popCount(self.observed_types) == 1;
    }
    
    pub fn isPolymorphic(self: *const TypeProfile) bool {
        const count = @popCount(self.observed_types);
        return count >= 2 and count <= 4;
    }
    
    pub fn isMegamorphic(self: *const TypeProfile) bool {
        return @popCount(self.observed_types) > 4;
    }
    
    pub fn getDominantType(self: *const TypeProfile) ?TypeId {
        if (self.total_observations == 0) return null;
        
        var max_count: u32 = 0;
        var max_idx: u8 = 0;
        
        for (self.type_counts, 0..) |count, i| {
            if (count > max_count) {
                max_count = count;
                max_idx = @intCast(i);
            }
        }
        
        // Dominant if > 90% of observations
        if (@as(f64, @floatFromInt(max_count)) / @as(f64, @floatFromInt(self.total_observations)) > 0.9) {
            return @enumFromInt(max_idx);
        }
        return null;
    }
    
    pub fn getTypeFrequency(self: *const TypeProfile, type_id: TypeId) f64 {
        if (self.total_observations == 0) return 0.0;
        const idx = @intFromEnum(type_id);
        return @as(f64, @floatFromInt(self.type_counts[idx])) / @as(f64, @floatFromInt(self.total_observations));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CALL SITE PROFILE - Профиль для точки вызова
// ═══════════════════════════════════════════════════════════════════════════════

pub const CallSiteProfile = struct {
    // Профили аргументов
    arg_profiles: [8]TypeProfile,
    num_args: u8,
    
    // Профиль возвращаемого значения
    return_profile: TypeProfile,
    
    // Статистика вызовов
    call_count: u64,
    inline_count: u64,  // Сколько раз был заинлайнен
    
    // Целевые функции (для polymorphic dispatch)
    targets: [4]?u32,  // Function IDs
    target_counts: [4]u32,
    num_targets: u8,
    
    pub fn init(num_args: u8) CallSiteProfile {
        return .{
            .arg_profiles = [_]TypeProfile{TypeProfile.init()} ** 8,
            .num_args = num_args,
            .return_profile = TypeProfile.init(),
            .call_count = 0,
            .inline_count = 0,
            .targets = [_]?u32{null} ** 4,
            .target_counts = [_]u32{0} ** 4,
            .num_targets = 0,
        };
    }
    
    pub fn recordCall(self: *CallSiteProfile, arg_types: []const TypeId, return_type: TypeId, target_id: u32) void {
        self.call_count += 1;
        
        // Record argument types
        for (arg_types, 0..) |arg_type, i| {
            if (i < self.num_args) {
                self.arg_profiles[i].record(arg_type);
            }
        }
        
        // Record return type
        self.return_profile.record(return_type);
        
        // Record target
        self.recordTarget(target_id);
    }
    
    fn recordTarget(self: *CallSiteProfile, target_id: u32) void {
        // Check if target already recorded
        for (self.targets, 0..) |maybe_target, i| {
            if (maybe_target) |target| {
                if (target == target_id) {
                    self.target_counts[i] += 1;
                    return;
                }
            }
        }
        
        // Add new target
        if (self.num_targets < 4) {
            self.targets[self.num_targets] = target_id;
            self.target_counts[self.num_targets] = 1;
            self.num_targets += 1;
        }
    }
    
    pub fn isMonomorphicCall(self: *const CallSiteProfile) bool {
        return self.num_targets == 1;
    }
    
    pub fn shouldInline(self: *const CallSiteProfile) bool {
        // Inline if:
        // 1. Monomorphic call site
        // 2. Called frequently (> 100 times)
        // 3. Arguments are type-stable
        if (!self.isMonomorphicCall()) return false;
        if (self.call_count < 100) return false;
        
        for (0..self.num_args) |i| {
            if (!self.arg_profiles[i].isMonomorphic()) return false;
        }
        
        return true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BRANCH PROFILE - Профиль для условных переходов
// ═══════════════════════════════════════════════════════════════════════════════

pub const BranchProfile = struct {
    taken_count: u64,
    not_taken_count: u64,
    
    pub fn init() BranchProfile {
        return .{
            .taken_count = 0,
            .not_taken_count = 0,
        };
    }
    
    pub fn recordTaken(self: *BranchProfile) void {
        self.taken_count +%= 1;
    }
    
    pub fn recordNotTaken(self: *BranchProfile) void {
        self.not_taken_count +%= 1;
    }
    
    pub fn getTakenProbability(self: *const BranchProfile) f64 {
        const total = self.taken_count + self.not_taken_count;
        if (total == 0) return 0.5;
        return @as(f64, @floatFromInt(self.taken_count)) / @as(f64, @floatFromInt(total));
    }
    
    pub fn isBiased(self: *const BranchProfile) bool {
        const prob = self.getTakenProbability();
        return prob > 0.9 or prob < 0.1;
    }
    
    pub fn getPredictedDirection(self: *const BranchProfile) bool {
        return self.getTakenProbability() > 0.5;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FEEDBACK COLLECTOR - Центральный сборщик feedback
// ═══════════════════════════════════════════════════════════════════════════════

pub const FeedbackCollector = struct {
    allocator: Allocator,
    
    // Профили по bytecode offset
    type_profiles: std.AutoHashMap(u32, TypeProfile),
    call_profiles: std.AutoHashMap(u32, CallSiteProfile),
    branch_profiles: std.AutoHashMap(u32, BranchProfile),
    
    // Статистика
    total_type_records: u64,
    total_call_records: u64,
    total_branch_records: u64,
    
    pub fn init(allocator: Allocator) FeedbackCollector {
        return .{
            .allocator = allocator,
            .type_profiles = std.AutoHashMap(u32, TypeProfile).init(allocator),
            .call_profiles = std.AutoHashMap(u32, CallSiteProfile).init(allocator),
            .branch_profiles = std.AutoHashMap(u32, BranchProfile).init(allocator),
            .total_type_records = 0,
            .total_call_records = 0,
            .total_branch_records = 0,
        };
    }
    
    pub fn deinit(self: *FeedbackCollector) void {
        self.type_profiles.deinit();
        self.call_profiles.deinit();
        self.branch_profiles.deinit();
    }
    
    pub fn recordType(self: *FeedbackCollector, offset: u32, type_id: TypeId) !void {
        const result = try self.type_profiles.getOrPut(offset);
        if (!result.found_existing) {
            result.value_ptr.* = TypeProfile.init();
        }
        result.value_ptr.record(type_id);
        self.total_type_records += 1;
    }
    
    pub fn recordCall(self: *FeedbackCollector, offset: u32, num_args: u8, arg_types: []const TypeId, return_type: TypeId, target_id: u32) !void {
        const result = try self.call_profiles.getOrPut(offset);
        if (!result.found_existing) {
            result.value_ptr.* = CallSiteProfile.init(num_args);
        }
        result.value_ptr.recordCall(arg_types, return_type, target_id);
        self.total_call_records += 1;
    }
    
    pub fn recordBranch(self: *FeedbackCollector, offset: u32, taken: bool) !void {
        const result = try self.branch_profiles.getOrPut(offset);
        if (!result.found_existing) {
            result.value_ptr.* = BranchProfile.init();
        }
        if (taken) {
            result.value_ptr.recordTaken();
        } else {
            result.value_ptr.recordNotTaken();
        }
        self.total_branch_records += 1;
    }
    
    pub fn getTypeProfile(self: *const FeedbackCollector, offset: u32) ?TypeProfile {
        return self.type_profiles.get(offset);
    }
    
    pub fn getCallProfile(self: *const FeedbackCollector, offset: u32) ?CallSiteProfile {
        return self.call_profiles.get(offset);
    }
    
    pub fn getBranchProfile(self: *const FeedbackCollector, offset: u32) ?BranchProfile {
        return self.branch_profiles.get(offset);
    }
    
    pub fn getStatistics(self: *const FeedbackCollector) FeedbackStatistics {
        var mono_types: u32 = 0;
        var poly_types: u32 = 0;
        var mega_types: u32 = 0;
        
        var iter = self.type_profiles.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.isMonomorphic()) {
                mono_types += 1;
            } else if (entry.value_ptr.isPolymorphic()) {
                poly_types += 1;
            } else if (entry.value_ptr.isMegamorphic()) {
                mega_types += 1;
            }
        }
        
        var biased_branches: u32 = 0;
        var branch_iter = self.branch_profiles.iterator();
        while (branch_iter.next()) |entry| {
            if (entry.value_ptr.isBiased()) {
                biased_branches += 1;
            }
        }
        
        return .{
            .total_type_sites = @intCast(self.type_profiles.count()),
            .monomorphic_sites = mono_types,
            .polymorphic_sites = poly_types,
            .megamorphic_sites = mega_types,
            .total_call_sites = @intCast(self.call_profiles.count()),
            .total_branch_sites = @intCast(self.branch_profiles.count()),
            .biased_branches = biased_branches,
        };
    }
};

pub const FeedbackStatistics = struct {
    total_type_sites: u32,
    monomorphic_sites: u32,
    polymorphic_sites: u32,
    megamorphic_sites: u32,
    total_call_sites: u32,
    total_branch_sites: u32,
    biased_branches: u32,
    
    pub fn getMonomorphicRatio(self: *const FeedbackStatistics) f64 {
        if (self.total_type_sites == 0) return 0.0;
        return @as(f64, @floatFromInt(self.monomorphic_sites)) / @as(f64, @floatFromInt(self.total_type_sites));
    }
    
    pub fn getBiasedBranchRatio(self: *const FeedbackStatistics) f64 {
        if (self.total_branch_sites == 0) return 0.0;
        return @as(f64, @floatFromInt(self.biased_branches)) / @as(f64, @floatFromInt(self.total_branch_sites));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "type profile monomorphic" {
    var profile = TypeProfile.init();
    
    profile.record(.int);
    profile.record(.int);
    profile.record(.int);
    
    try std.testing.expect(profile.isMonomorphic());
    try std.testing.expect(!profile.isPolymorphic());
    try std.testing.expectEqual(TypeId.int, profile.getDominantType().?);
}

test "type profile polymorphic" {
    var profile = TypeProfile.init();
    
    profile.record(.int);
    profile.record(.float);
    
    try std.testing.expect(!profile.isMonomorphic());
    try std.testing.expect(profile.isPolymorphic());
}

test "call site profile" {
    var profile = CallSiteProfile.init(2);
    
    const args1 = [_]TypeId{ .int, .int };
    profile.recordCall(&args1, .int, 1);
    profile.recordCall(&args1, .int, 1);
    
    try std.testing.expect(profile.isMonomorphicCall());
    try std.testing.expectEqual(@as(u64, 2), profile.call_count);
}

test "branch profile biased" {
    var profile = BranchProfile.init();
    
    for (0..95) |_| profile.recordTaken();
    for (0..5) |_| profile.recordNotTaken();
    
    try std.testing.expect(profile.isBiased());
    try std.testing.expect(profile.getPredictedDirection());
}

test "feedback collector" {
    var collector = FeedbackCollector.init(std.testing.allocator);
    defer collector.deinit();
    
    try collector.recordType(0, .int);
    try collector.recordType(0, .int);
    try collector.recordType(4, .float);
    
    try collector.recordBranch(8, true);
    try collector.recordBranch(8, true);
    try collector.recordBranch(8, false);
    
    const stats = collector.getStatistics();
    try std.testing.expectEqual(@as(u32, 2), stats.total_type_sites);
    try std.testing.expectEqual(@as(u32, 1), stats.total_branch_sites);
}

//! VIBEE Constant Folder - PAS DAEMON V40
//! Паттерны: PRE (compile-time evaluation), ALG (algebraic simplification), D&C (recursive folding)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.6180339887498948482;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;
pub const TAU: f64 = PI * 2.0;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANT VALUE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConstKind = enum {
    int,
    float,
    boolean,
    string,
    null_val,
    sacred_phi,
    sacred_pi,
    sacred_e,
};

pub const ConstValue = struct {
    kind: ConstKind,
    data: ConstData,
    
    pub const ConstData = union {
        int: i64,
        float: f64,
        boolean: bool,
        string: []const u8,
    };
    
    pub fn int(v: i64) ConstValue {
        return .{ .kind = .int, .data = .{ .int = v } };
    }
    
    pub fn float(v: f64) ConstValue {
        return .{ .kind = .float, .data = .{ .float = v } };
    }
    
    pub fn boolean(v: bool) ConstValue {
        return .{ .kind = .boolean, .data = .{ .boolean = v } };
    }
    
    pub fn phi() ConstValue {
        return .{ .kind = .sacred_phi, .data = .{ .float = PHI } };
    }
    
    pub fn pi() ConstValue {
        return .{ .kind = .sacred_pi, .data = .{ .float = PI } };
    }
    
    pub fn e_const() ConstValue {
        return .{ .kind = .sacred_e, .data = .{ .float = E } };
    }
    
    pub fn asFloat(self: ConstValue) ?f64 {
        return switch (self.kind) {
            .int => @floatFromInt(self.data.int),
            .float, .sacred_phi, .sacred_pi, .sacred_e => self.data.float,
            else => null,
        };
    }
    
    pub fn asInt(self: ConstValue) ?i64 {
        return switch (self.kind) {
            .int => self.data.int,
            .float => @intFromFloat(self.data.float),
            else => null,
        };
    }
    
    pub fn asBool(self: ConstValue) ?bool {
        return switch (self.kind) {
            .boolean => self.data.boolean,
            .int => self.data.int != 0,
            else => null,
        };
    }
    
    pub fn isNumeric(self: ConstValue) bool {
        return self.kind == .int or self.kind == .float or 
               self.kind == .sacred_phi or self.kind == .sacred_pi or self.kind == .sacred_e;
    }
    
    pub fn isSacred(self: ConstValue) bool {
        return self.kind == .sacred_phi or self.kind == .sacred_pi or self.kind == .sacred_e;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXPRESSION NODE - For constant folding
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExprOp = enum {
    // Arithmetic
    add,
    sub,
    mul,
    div,
    mod,
    neg,
    
    // Bitwise
    band,
    bor,
    bxor,
    bnot,
    shl,
    shr,
    
    // Comparison
    eq,
    ne,
    lt,
    le,
    gt,
    ge,
    
    // Logical
    land,
    lor,
    lnot,
    
    // Math functions
    pow,
    sqrt,
    ln,
    exp,
    sin,
    cos,
    
    // Constant
    constant,
    
    // Variable (not foldable)
    variable,
};

pub const Expr = struct {
    op: ExprOp,
    left: ?*Expr = null,
    right: ?*Expr = null,
    value: ?ConstValue = null,
    var_name: ?[]const u8 = null,
    
    pub fn constant(val: ConstValue) Expr {
        return .{ .op = .constant, .value = val };
    }
    
    pub fn variable(name: []const u8) Expr {
        return .{ .op = .variable, .var_name = name };
    }
    
    pub fn unary(op: ExprOp, operand: *Expr) Expr {
        return .{ .op = op, .left = operand };
    }
    
    pub fn binary(op: ExprOp, left: *Expr, right: *Expr) Expr {
        return .{ .op = op, .left = left, .right = right };
    }
    
    pub fn isConstant(self: *const Expr) bool {
        return self.op == .constant and self.value != null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANT FOLDER - Main folding engine
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConstantFolder = struct {
    allocator: Allocator,
    
    // Statistics
    folds_performed: u64 = 0,
    sacred_folds: u64 = 0,
    strength_reductions: u64 = 0,
    
    pub fn init(allocator: Allocator) ConstantFolder {
        return .{ .allocator = allocator };
    }
    
    /// Fold expression recursively (D&C pattern)
    pub fn fold(self: *ConstantFolder, expr: *Expr) ?ConstValue {
        switch (expr.op) {
            .constant => return expr.value,
            .variable => return null,
            
            // Unary operations
            .neg => return self.foldUnary(expr, negateValue),
            .bnot => return self.foldUnary(expr, bitwiseNot),
            .lnot => return self.foldUnary(expr, logicalNot),
            .sqrt => return self.foldUnary(expr, sqrtValue),
            .ln => return self.foldUnary(expr, lnValue),
            .exp => return self.foldUnary(expr, expValue),
            .sin => return self.foldUnary(expr, sinValue),
            .cos => return self.foldUnary(expr, cosValue),
            
            // Binary operations
            .add => return self.foldBinary(expr, addValues),
            .sub => return self.foldBinary(expr, subValues),
            .mul => return self.foldBinaryWithStrength(expr, mulValues),
            .div => return self.foldBinaryWithStrength(expr, divValues),
            .mod => return self.foldBinary(expr, modValues),
            .pow => return self.foldBinary(expr, powValues),
            
            .band => return self.foldBinary(expr, bandValues),
            .bor => return self.foldBinary(expr, borValues),
            .bxor => return self.foldBinary(expr, bxorValues),
            .shl => return self.foldBinary(expr, shlValues),
            .shr => return self.foldBinary(expr, shrValues),
            
            .eq => return self.foldComparison(expr, eqValues),
            .ne => return self.foldComparison(expr, neValues),
            .lt => return self.foldComparison(expr, ltValues),
            .le => return self.foldComparison(expr, leValues),
            .gt => return self.foldComparison(expr, gtValues),
            .ge => return self.foldComparison(expr, geValues),
            
            .land => return self.foldLogical(expr, landValues),
            .lor => return self.foldLogical(expr, lorValues),
        }
    }
    
    fn foldUnary(self: *ConstantFolder, expr: *Expr, op_fn: *const fn (ConstValue) ?ConstValue) ?ConstValue {
        if (expr.left) |left| {
            if (self.fold(left)) |val| {
                if (op_fn(val)) |result| {
                    self.folds_performed += 1;
                    return result;
                }
            }
        }
        return null;
    }
    
    fn foldBinary(self: *ConstantFolder, expr: *Expr, op_fn: *const fn (ConstValue, ConstValue) ?ConstValue) ?ConstValue {
        if (expr.left) |left| {
            if (expr.right) |right| {
                if (self.fold(left)) |lval| {
                    if (self.fold(right)) |rval| {
                        if (op_fn(lval, rval)) |result| {
                            self.folds_performed += 1;
                            if (lval.isSacred() or rval.isSacred()) {
                                self.sacred_folds += 1;
                            }
                            return result;
                        }
                    }
                }
            }
        }
        return null;
    }
    
    fn foldBinaryWithStrength(self: *ConstantFolder, expr: *Expr, op_fn: *const fn (ConstValue, ConstValue) ?ConstValue) ?ConstValue {
        // Try strength reduction first
        if (self.tryStrengthReduction(expr)) |result| {
            self.strength_reductions += 1;
            return result;
        }
        return self.foldBinary(expr, op_fn);
    }
    
    fn foldComparison(self: *ConstantFolder, expr: *Expr, op_fn: *const fn (ConstValue, ConstValue) ?bool) ?ConstValue {
        if (expr.left) |left| {
            if (expr.right) |right| {
                if (self.fold(left)) |lval| {
                    if (self.fold(right)) |rval| {
                        if (op_fn(lval, rval)) |result| {
                            self.folds_performed += 1;
                            return ConstValue.boolean(result);
                        }
                    }
                }
            }
        }
        return null;
    }
    
    fn foldLogical(self: *ConstantFolder, expr: *Expr, op_fn: *const fn (bool, bool) bool) ?ConstValue {
        if (expr.left) |left| {
            if (expr.right) |right| {
                if (self.fold(left)) |lval| {
                    if (self.fold(right)) |rval| {
                        if (lval.asBool()) |lb| {
                            if (rval.asBool()) |rb| {
                                self.folds_performed += 1;
                                return ConstValue.boolean(op_fn(lb, rb));
                            }
                        }
                    }
                }
            }
        }
        return null;
    }
    
    /// Strength reduction for multiplication/division by powers of 2
    fn tryStrengthReduction(self: *ConstantFolder, expr: *Expr) ?ConstValue {
        _ = self;
        if (expr.right) |right| {
            if (right.isConstant()) {
                if (right.value) |val| {
                    if (val.asInt()) |n| {
                        // Check if power of 2
                        if (n > 0 and (n & (n - 1)) == 0) {
                            // Could emit shift instead, but for folding we just compute
                            return null;
                        }
                    }
                }
            }
        }
        return null;
    }
    
    /// Check for golden identity: φ² + 1/φ² = 3
    pub fn checkGoldenIdentity(self: *ConstantFolder, expr: *Expr) ?ConstValue {
        _ = self;
        // Pattern: phi * phi + 1 / (phi * phi)
        if (expr.op == .add) {
            if (expr.left) |left| {
                if (expr.right) |right| {
                    if (isPhiSquared(left) and isInversePhiSquared(right)) {
                        return ConstValue.float(GOLDEN_IDENTITY);
                    }
                }
            }
        }
        return null;
    }
    
    fn isPhiSquared(expr: *Expr) bool {
        if (expr.op == .mul) {
            if (expr.left) |left| {
                if (expr.right) |right| {
                    if (left.isConstant() and right.isConstant()) {
                        if (left.value) |lv| {
                            if (right.value) |rv| {
                                return lv.kind == .sacred_phi and rv.kind == .sacred_phi;
                            }
                        }
                    }
                }
            }
        }
        return false;
    }
    
    fn isInversePhiSquared(expr: *Expr) bool {
        if (expr.op == .div) {
            if (expr.left) |left| {
                if (expr.right) |right| {
                    if (left.isConstant()) {
                        if (left.value) |lv| {
                            if (lv.asFloat()) |f| {
                                if (@abs(f - 1.0) < 0.0001) {
                                    return isPhiSquared(right);
                                }
                            }
                        }
                    }
                }
            }
        }
        return false;
    }
    
    /// Get statistics
    pub fn getStats(self: *const ConstantFolder) FolderStats {
        return .{
            .folds_performed = self.folds_performed,
            .sacred_folds = self.sacred_folds,
            .strength_reductions = self.strength_reductions,
        };
    }
};

pub const FolderStats = struct {
    folds_performed: u64,
    sacred_folds: u64,
    strength_reductions: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// OPERATION IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn negateValue(v: ConstValue) ?ConstValue {
    return switch (v.kind) {
        .int => ConstValue.int(-v.data.int),
        .float, .sacred_phi, .sacred_pi, .sacred_e => ConstValue.float(-v.data.float),
        else => null,
    };
}

fn bitwiseNot(v: ConstValue) ?ConstValue {
    if (v.kind == .int) return ConstValue.int(~v.data.int);
    return null;
}

fn logicalNot(v: ConstValue) ?ConstValue {
    if (v.asBool()) |b| return ConstValue.boolean(!b);
    return null;
}

fn sqrtValue(v: ConstValue) ?ConstValue {
    if (v.asFloat()) |f| {
        if (f >= 0) return ConstValue.float(@sqrt(f));
    }
    return null;
}

fn lnValue(v: ConstValue) ?ConstValue {
    if (v.asFloat()) |f| {
        if (f > 0) return ConstValue.float(@log(f));
    }
    return null;
}

fn expValue(v: ConstValue) ?ConstValue {
    if (v.asFloat()) |f| return ConstValue.float(@exp(f));
    return null;
}

fn sinValue(v: ConstValue) ?ConstValue {
    if (v.asFloat()) |f| return ConstValue.float(@sin(f));
    return null;
}

fn cosValue(v: ConstValue) ?ConstValue {
    if (v.asFloat()) |f| return ConstValue.float(@cos(f));
    return null;
}

fn addValues(a: ConstValue, b: ConstValue) ?ConstValue {
    if (a.kind == .int and b.kind == .int) {
        return ConstValue.int(a.data.int + b.data.int);
    }
    if (a.asFloat()) |af| {
        if (b.asFloat()) |bf| {
            return ConstValue.float(af + bf);
        }
    }
    return null;
}

fn subValues(a: ConstValue, b: ConstValue) ?ConstValue {
    if (a.kind == .int and b.kind == .int) {
        return ConstValue.int(a.data.int - b.data.int);
    }
    if (a.asFloat()) |af| {
        if (b.asFloat()) |bf| {
            return ConstValue.float(af - bf);
        }
    }
    return null;
}

fn mulValues(a: ConstValue, b: ConstValue) ?ConstValue {
    if (a.kind == .int and b.kind == .int) {
        return ConstValue.int(a.data.int * b.data.int);
    }
    if (a.asFloat()) |af| {
        if (b.asFloat()) |bf| {
            return ConstValue.float(af * bf);
        }
    }
    return null;
}

fn divValues(a: ConstValue, b: ConstValue) ?ConstValue {
    if (a.kind == .int and b.kind == .int) {
        if (b.data.int != 0) {
            return ConstValue.int(@divTrunc(a.data.int, b.data.int));
        }
    }
    if (a.asFloat()) |af| {
        if (b.asFloat()) |bf| {
            if (bf != 0) return ConstValue.float(af / bf);
        }
    }
    return null;
}

fn modValues(a: ConstValue, b: ConstValue) ?ConstValue {
    if (a.kind == .int and b.kind == .int) {
        if (b.data.int != 0) {
            return ConstValue.int(@mod(a.data.int, b.data.int));
        }
    }
    return null;
}

fn powValues(a: ConstValue, b: ConstValue) ?ConstValue {
    if (a.asFloat()) |af| {
        if (b.asFloat()) |bf| {
            return ConstValue.float(std.math.pow(f64, af, bf));
        }
    }
    return null;
}

fn bandValues(a: ConstValue, b: ConstValue) ?ConstValue {
    if (a.kind == .int and b.kind == .int) {
        return ConstValue.int(a.data.int & b.data.int);
    }
    return null;
}

fn borValues(a: ConstValue, b: ConstValue) ?ConstValue {
    if (a.kind == .int and b.kind == .int) {
        return ConstValue.int(a.data.int | b.data.int);
    }
    return null;
}

fn bxorValues(a: ConstValue, b: ConstValue) ?ConstValue {
    if (a.kind == .int and b.kind == .int) {
        return ConstValue.int(a.data.int ^ b.data.int);
    }
    return null;
}

fn shlValues(a: ConstValue, b: ConstValue) ?ConstValue {
    if (a.kind == .int and b.kind == .int) {
        if (b.data.int >= 0 and b.data.int < 64) {
            return ConstValue.int(a.data.int << @intCast(b.data.int));
        }
    }
    return null;
}

fn shrValues(a: ConstValue, b: ConstValue) ?ConstValue {
    if (a.kind == .int and b.kind == .int) {
        if (b.data.int >= 0 and b.data.int < 64) {
            return ConstValue.int(a.data.int >> @intCast(b.data.int));
        }
    }
    return null;
}

fn eqValues(a: ConstValue, b: ConstValue) ?bool {
    if (a.kind == .int and b.kind == .int) return a.data.int == b.data.int;
    if (a.asFloat()) |af| {
        if (b.asFloat()) |bf| return @abs(af - bf) < 0.0001;
    }
    return null;
}

fn neValues(a: ConstValue, b: ConstValue) ?bool {
    if (eqValues(a, b)) |eq| return !eq;
    return null;
}

fn ltValues(a: ConstValue, b: ConstValue) ?bool {
    if (a.kind == .int and b.kind == .int) return a.data.int < b.data.int;
    if (a.asFloat()) |af| {
        if (b.asFloat()) |bf| return af < bf;
    }
    return null;
}

fn leValues(a: ConstValue, b: ConstValue) ?bool {
    if (a.kind == .int and b.kind == .int) return a.data.int <= b.data.int;
    if (a.asFloat()) |af| {
        if (b.asFloat()) |bf| return af <= bf;
    }
    return null;
}

fn gtValues(a: ConstValue, b: ConstValue) ?bool {
    if (a.kind == .int and b.kind == .int) return a.data.int > b.data.int;
    if (a.asFloat()) |af| {
        if (b.asFloat()) |bf| return af > bf;
    }
    return null;
}

fn geValues(a: ConstValue, b: ConstValue) ?bool {
    if (a.kind == .int and b.kind == .int) return a.data.int >= b.data.int;
    if (a.asFloat()) |af| {
        if (b.asFloat()) |bf| return af >= bf;
    }
    return null;
}

fn landValues(a: bool, b: bool) bool {
    return a and b;
}

fn lorValues(a: bool, b: bool) bool {
    return a or b;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "fold integer arithmetic" {
    const allocator = std.testing.allocator;
    var folder = ConstantFolder.init(allocator);
    
    var c1 = Expr.constant(ConstValue.int(10));
    var c2 = Expr.constant(ConstValue.int(5));
    var add_expr = Expr.binary(.add, &c1, &c2);
    
    const result = folder.fold(&add_expr).?;
    try std.testing.expectEqual(@as(i64, 15), result.data.int);
}

test "fold float arithmetic" {
    const allocator = std.testing.allocator;
    var folder = ConstantFolder.init(allocator);
    
    var c1 = Expr.constant(ConstValue.float(3.14));
    var c2 = Expr.constant(ConstValue.float(2.0));
    var mul_expr = Expr.binary(.mul, &c1, &c2);
    
    const result = folder.fold(&mul_expr).?;
    try std.testing.expect(@abs(result.data.float - 6.28) < 0.01);
}

test "fold sacred phi" {
    const allocator = std.testing.allocator;
    var folder = ConstantFolder.init(allocator);
    
    var phi1 = Expr.constant(ConstValue.phi());
    var phi2 = Expr.constant(ConstValue.phi());
    var mul_expr = Expr.binary(.mul, &phi1, &phi2);
    
    const result = folder.fold(&mul_expr).?;
    const phi_squared = PHI * PHI;
    try std.testing.expect(@abs(result.data.float - phi_squared) < 0.0001);
    
    try std.testing.expect(folder.sacred_folds > 0);
}

test "fold comparison" {
    const allocator = std.testing.allocator;
    var folder = ConstantFolder.init(allocator);
    
    var c1 = Expr.constant(ConstValue.int(10));
    var c2 = Expr.constant(ConstValue.int(5));
    var lt_expr = Expr.binary(.lt, &c1, &c2);
    
    const result = folder.fold(&lt_expr).?;
    try std.testing.expectEqual(false, result.data.boolean);
}

test "fold nested expression" {
    const allocator = std.testing.allocator;
    var folder = ConstantFolder.init(allocator);
    
    // (2 + 3) * 4 = 20
    var c2 = Expr.constant(ConstValue.int(2));
    var c3 = Expr.constant(ConstValue.int(3));
    var c4 = Expr.constant(ConstValue.int(4));
    var add_expr = Expr.binary(.add, &c2, &c3);
    var mul_expr = Expr.binary(.mul, &add_expr, &c4);
    
    const result = folder.fold(&mul_expr).?;
    try std.testing.expectEqual(@as(i64, 20), result.data.int);
}

test "fold math functions" {
    const allocator = std.testing.allocator;
    var folder = ConstantFolder.init(allocator);
    
    var c4 = Expr.constant(ConstValue.float(4.0));
    var sqrt_expr = Expr.unary(.sqrt, &c4);
    
    const result = folder.fold(&sqrt_expr).?;
    try std.testing.expect(@abs(result.data.float - 2.0) < 0.0001);
}

test "fold bitwise operations" {
    const allocator = std.testing.allocator;
    var folder = ConstantFolder.init(allocator);
    
    var c1 = Expr.constant(ConstValue.int(0b1010));
    var c2 = Expr.constant(ConstValue.int(0b1100));
    var and_expr = Expr.binary(.band, &c1, &c2);
    
    const result = folder.fold(&and_expr).?;
    try std.testing.expectEqual(@as(i64, 0b1000), result.data.int);
}

test "variable not foldable" {
    const allocator = std.testing.allocator;
    var folder = ConstantFolder.init(allocator);
    
    var var_expr = Expr.variable("x");
    const result = folder.fold(&var_expr);
    try std.testing.expect(result == null);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}

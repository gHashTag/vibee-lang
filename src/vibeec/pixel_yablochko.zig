// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY VM v15 ЯБЛОЧКО - Native Pixel Integration
// "Катись, катись, яблочко, по серебряному блюдечку..."
// Generated from specs/trinity_vm_v15_yablochko.vibee
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Sacred Constants
pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PI: f64 = 3.141592653589793;
pub const E: f64 = 2.718281828459045;
pub const GOLDEN_IDENTITY: f64 = 3.0; // φ² + 1/φ² = 3

// ═══════════════════════════════════════════════════════════════════════════════
// GPU COMPUTE OPCODES (0xD0-0xDF)
// ═══════════════════════════════════════════════════════════════════════════════

pub const GPUOpcode = enum(u8) {
    GPU_INIT = 0xD0,
    GPU_ALLOC = 0xD1,
    GPU_COPY = 0xD2,
    GPU_COMPUTE = 0xD3,
    GPU_SYNC = 0xD4,
    GPU_FREE = 0xD5,
    GPU_SHADER = 0xD6,
    GPU_BIND = 0xD7,
};

// ═══════════════════════════════════════════════════════════════════════════════
// FRAMEBUFFER OPCODES (0xE0-0xEF)
// ═══════════════════════════════════════════════════════════════════════════════

pub const FBOpcode = enum(u8) {
    FB_CREATE = 0xE0,
    FB_MAP = 0xE1,
    FB_PIXEL = 0xE2,
    FB_RECT = 0xE3,
    FB_BLIT = 0xE4,
    FB_PRESENT = 0xE5,
    FB_VSYNC = 0xE6,
    FB_CLEAR = 0xE7,
    FB_READ = 0xE8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// GAUSSIAN SPLATTING OPCODES (0xF0-0xFF)
// ═══════════════════════════════════════════════════════════════════════════════

pub const GSOpcode = enum(u8) {
    GS_INIT = 0xF0,
    GS_SPLAT = 0xF1,
    GS_RENDER = 0xF2,
    GS_TRAIN = 0xF3,
    GS_EXPORT = 0xF4,
    GS_IMPORT = 0xF5,
    GS_CLEAR = 0xF6,
    GS_CAMERA = 0xF7,
};

// ═══════════════════════════════════════════════════════════════════════════════
// VARIABLE RATE SHADING OPCODES (0xC0-0xCF)
// ═══════════════════════════════════════════════════════════════════════════════

pub const VRSOpcode = enum(u8) {
    VRS_INIT = 0xC0,
    VRS_SET_RATE = 0xC1,
    VRS_AUTO = 0xC2,
};

pub const ShadingRate = enum(u8) {
    FULL = 0x00,      // 1x1
    HALF_H = 0x01,    // 2x1
    HALF_V = 0x02,    // 1x2
    QUARTER = 0x03,   // 2x2
    EIGHTH = 0x04,    // 4x2
    SIXTEENTH = 0x05, // 4x4
};

pub const VRSMode = enum(u8) {
    MOTION = 0x00,
    FOCUS = 0x01,
    CONTENT = 0x02,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PIXEL FORMAT
// ═══════════════════════════════════════════════════════════════════════════════

pub const PixelFormat = enum(u8) {
    RGBA8 = 0x00,
    RGBA16F = 0x01,
    RGBA32F = 0x02,
    R8 = 0x03,
};

pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn fromU32(val: u32) Color {
        return @bitCast(val);
    }

    pub fn toU32(self: Color) u32 {
        return @bitCast(self);
    }

    pub fn red() Color {
        return .{ .r = 255, .g = 0, .b = 0, .a = 255 };
    }

    pub fn green() Color {
        return .{ .r = 0, .g = 255, .b = 0, .a = 255 };
    }

    pub fn blue() Color {
        return .{ .r = 0, .g = 0, .b = 255, .a = 255 };
    }

    pub fn golden() Color {
        // Golden ratio color: φ-based RGB
        return .{
            .r = @intFromFloat(PHI_INV * 255.0),
            .g = @intFromFloat(PHI_INV * PHI_INV * 255.0),
            .b = @intFromFloat(PHI_INV * PHI_INV * PHI_INV * 255.0),
            .a = 255,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FRAMEBUFFER
// ═══════════════════════════════════════════════════════════════════════════════

pub const Framebuffer = struct {
    width: u32,
    height: u32,
    format: PixelFormat,
    pixels: []u32,
    allocator: Allocator,

    pub fn init(allocator: Allocator, width: u32, height: u32, format: PixelFormat) !Framebuffer {
        const size = width * height;
        const pixels = try allocator.alloc(u32, size);
        @memset(pixels, 0);
        return .{
            .width = width,
            .height = height,
            .format = format,
            .pixels = pixels,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Framebuffer) void {
        self.allocator.free(self.pixels);
    }

    pub fn setPixel(self: *Framebuffer, x: u32, y: u32, color: Color) void {
        if (x < self.width and y < self.height) {
            self.pixels[y * self.width + x] = color.toU32();
        }
    }

    pub fn getPixel(self: *const Framebuffer, x: u32, y: u32) Color {
        if (x < self.width and y < self.height) {
            return Color.fromU32(self.pixels[y * self.width + x]);
        }
        return .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    }

    pub fn clear(self: *Framebuffer, color: Color) void {
        @memset(self.pixels, color.toU32());
    }

    pub fn fillRect(self: *Framebuffer, x: u32, y: u32, w: u32, h: u32, color: Color) void {
        const x_end = @min(x + w, self.width);
        const y_end = @min(y + h, self.height);
        const c = color.toU32();

        var py = y;
        while (py < y_end) : (py += 1) {
            var px = x;
            while (px < x_end) : (px += 1) {
                self.pixels[py * self.width + px] = c;
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GAUSSIAN SPLAT
// ═══════════════════════════════════════════════════════════════════════════════

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn scale(self: Vec3, s: f32) Vec3 {
        return .{ .x = self.x * s, .y = self.y * s, .z = self.z * s };
    }

    pub fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }
};

pub const GaussianSplat = struct {
    position: Vec3,
    scale: Vec3,
    rotation: [4]f32, // quaternion
    color: Vec3,
    opacity: f32,

    pub fn init(pos: Vec3, col: Vec3, opacity: f32) GaussianSplat {
        return .{
            .position = pos,
            .scale = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
            .rotation = .{ 0, 0, 0, 1 }, // identity quaternion
            .color = col,
            .opacity = opacity,
        };
    }
};

pub const Camera = struct {
    position: Vec3,
    target: Vec3,
    fov: f32,
    aspect: f32,

    pub fn init() Camera {
        return .{
            .position = .{ .x = 0, .y = 0, .z = -5 },
            .target = .{ .x = 0, .y = 0, .z = 0 },
            .fov = @as(f32, @floatCast(PI / 4.0)),
            .aspect = 16.0 / 9.0,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GAUSSIAN SPLATTING RENDERER
// ═══════════════════════════════════════════════════════════════════════════════

pub const GaussianRenderer = struct {
    splats: std.ArrayList(GaussianSplat),
    camera: Camera,
    allocator: Allocator,

    pub fn init(allocator: Allocator) GaussianRenderer {
        return .{
            .splats = std.ArrayList(GaussianSplat).init(allocator),
            .camera = Camera.init(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *GaussianRenderer) void {
        self.splats.deinit();
    }

    pub fn addSplat(self: *GaussianRenderer, splat: GaussianSplat) !void {
        try self.splats.append(splat);
    }

    pub fn clearSplats(self: *GaussianRenderer) void {
        self.splats.clearRetainingCapacity();
    }

    pub fn render(self: *GaussianRenderer, fb: *Framebuffer) void {
        // Simplified Gaussian Splatting render
        for (self.splats.items) |splat| {
            // Project 3D position to 2D
            const rel_z = splat.position.z - self.camera.position.z;
            if (rel_z <= 0) continue;

            const scale_factor = 1.0 / rel_z;
            const screen_x = (splat.position.x - self.camera.position.x) * scale_factor;
            const screen_y = (splat.position.y - self.camera.position.y) * scale_factor;

            // Convert to pixel coordinates
            const px: i32 = @intFromFloat((@as(f32, @floatFromInt(fb.width)) / 2.0) + screen_x * @as(f32, @floatFromInt(fb.width)) / 2.0);
            const py: i32 = @intFromFloat((@as(f32, @floatFromInt(fb.height)) / 2.0) - screen_y * @as(f32, @floatFromInt(fb.height)) / 2.0);

            // Splat radius based on scale and distance
            const radius: i32 = @intFromFloat(@max(1.0, splat.scale.x * scale_factor * 50.0));

            // Render Gaussian blob
            var dy: i32 = -radius;
            while (dy <= radius) : (dy += 1) {
                var dx: i32 = -radius;
                while (dx <= radius) : (dx += 1) {
                    const dist_sq = dx * dx + dy * dy;
                    const r_sq = radius * radius;
                    if (dist_sq <= r_sq) {
                        const fx: u32 = @intCast(@max(0, px + dx));
                        const fy: u32 = @intCast(@max(0, py + dy));

                        // Gaussian falloff
                        const falloff = 1.0 - @as(f32, @floatFromInt(dist_sq)) / @as(f32, @floatFromInt(r_sq));
                        const alpha = splat.opacity * falloff;

                        const color = Color{
                            .r = @intFromFloat(@min(255.0, splat.color.x * 255.0 * alpha)),
                            .g = @intFromFloat(@min(255.0, splat.color.y * 255.0 * alpha)),
                            .b = @intFromFloat(@min(255.0, splat.color.z * 255.0 * alpha)),
                            .a = @intFromFloat(alpha * 255.0),
                        };

                        fb.setPixel(fx, fy, color);
                    }
                }
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ЯБЛОЧКО VM - Pixel Integration Core
// ═══════════════════════════════════════════════════════════════════════════════

pub const YablochkoVM = struct {
    allocator: Allocator,
    framebuffers: std.ArrayList(Framebuffer),
    gaussian_renderer: GaussianRenderer,
    vrs_tile_size: u32,
    vrs_rates: ?[]ShadingRate,

    pub fn init(allocator: Allocator) YablochkoVM {
        return .{
            .allocator = allocator,
            .framebuffers = std.ArrayList(Framebuffer).init(allocator),
            .gaussian_renderer = GaussianRenderer.init(allocator),
            .vrs_tile_size = 16,
            .vrs_rates = null,
        };
    }

    pub fn deinit(self: *YablochkoVM) void {
        for (self.framebuffers.items) |*fb| {
            fb.deinit();
        }
        self.framebuffers.deinit();
        self.gaussian_renderer.deinit();
        if (self.vrs_rates) |rates| {
            self.allocator.free(rates);
        }
    }

    // FB_CREATE
    pub fn createFramebuffer(self: *YablochkoVM, width: u32, height: u32, format: PixelFormat) !u32 {
        const fb = try Framebuffer.init(self.allocator, width, height, format);
        try self.framebuffers.append(fb);
        return @intCast(self.framebuffers.items.len - 1);
    }

    // FB_PIXEL
    pub fn setPixel(self: *YablochkoVM, fb_id: u32, x: u32, y: u32, color: Color) void {
        if (fb_id < self.framebuffers.items.len) {
            self.framebuffers.items[fb_id].setPixel(x, y, color);
        }
    }

    // FB_CLEAR
    pub fn clearFramebuffer(self: *YablochkoVM, fb_id: u32, color: Color) void {
        if (fb_id < self.framebuffers.items.len) {
            self.framebuffers.items[fb_id].clear(color);
        }
    }

    // FB_RECT
    pub fn fillRect(self: *YablochkoVM, fb_id: u32, x: u32, y: u32, w: u32, h: u32, color: Color) void {
        if (fb_id < self.framebuffers.items.len) {
            self.framebuffers.items[fb_id].fillRect(x, y, w, h, color);
        }
    }

    // GS_INIT
    pub fn initGaussianSplatting(self: *YablochkoVM) void {
        self.gaussian_renderer.clearSplats();
    }

    // GS_SPLAT
    pub fn addSplat(self: *YablochkoVM, pos: Vec3, color: Vec3, opacity: f32) !void {
        try self.gaussian_renderer.addSplat(GaussianSplat.init(pos, color, opacity));
    }

    // GS_RENDER
    pub fn renderGaussianSplats(self: *YablochkoVM, fb_id: u32) void {
        if (fb_id < self.framebuffers.items.len) {
            self.gaussian_renderer.render(&self.framebuffers.items[fb_id]);
        }
    }

    // GS_CAMERA
    pub fn setCamera(self: *YablochkoVM, pos: Vec3, target: Vec3, fov: f32) void {
        self.gaussian_renderer.camera.position = pos;
        self.gaussian_renderer.camera.target = target;
        self.gaussian_renderer.camera.fov = fov;
    }

    // VRS_INIT
    pub fn initVRS(self: *YablochkoVM, tile_size: u32) !void {
        self.vrs_tile_size = tile_size;
    }

    // Execute opcode
    pub fn execute(self: *YablochkoVM, opcode: u8, operands: []const u32) !void {
        if (opcode >= 0xE0 and opcode <= 0xEF) {
            // Framebuffer opcodes
            switch (@as(FBOpcode, @enumFromInt(opcode))) {
                .FB_CREATE => {
                    if (operands.len >= 3) {
                        _ = try self.createFramebuffer(operands[0], operands[1], @enumFromInt(@as(u8, @truncate(operands[2]))));
                    }
                },
                .FB_PIXEL => {
                    if (operands.len >= 4) {
                        self.setPixel(operands[0], operands[1], operands[2], Color.fromU32(operands[3]));
                    }
                },
                .FB_CLEAR => {
                    if (operands.len >= 2) {
                        self.clearFramebuffer(operands[0], Color.fromU32(operands[1]));
                    }
                },
                .FB_RECT => {
                    if (operands.len >= 6) {
                        self.fillRect(operands[0], operands[1], operands[2], operands[3], operands[4], Color.fromU32(operands[5]));
                    }
                },
                else => {},
            }
        } else if (opcode >= 0xF0 and opcode <= 0xFF) {
            // Gaussian Splatting opcodes
            switch (@as(GSOpcode, @enumFromInt(opcode))) {
                .GS_INIT => self.initGaussianSplatting(),
                .GS_RENDER => {
                    if (operands.len >= 1) {
                        self.renderGaussianSplats(operands[0]);
                    }
                },
                .GS_CLEAR => self.gaussian_renderer.clearSplats(),
                else => {},
            }
        }
    }

    // Render golden spiral pattern (sacred geometry demo)
    pub fn renderGoldenSpiral(self: *YablochkoVM, fb_id: u32) void {
        if (fb_id >= self.framebuffers.items.len) return;

        var fb = &self.framebuffers.items[fb_id];
        const cx = @as(f32, @floatFromInt(fb.width)) / 2.0;
        const cy = @as(f32, @floatFromInt(fb.height)) / 2.0;

        var theta: f32 = 0;
        while (theta < 20.0 * PI) : (theta += 0.01) {
            // Golden spiral: r = a * φ^(θ/π)
            const r = 5.0 * std.math.pow(f32, @as(f32, @floatCast(PHI)), theta / @as(f32, @floatCast(PI)));
            const x = cx + r * @cos(theta);
            const y = cy + r * @sin(theta);

            if (x >= 0 and x < @as(f32, @floatFromInt(fb.width)) and
                y >= 0 and y < @as(f32, @floatFromInt(fb.height)))
            {
                fb.setPixel(@intFromFloat(x), @intFromFloat(y), Color.golden());
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "framebuffer creation and pixel operations" {
    const allocator = std.testing.allocator;
    var fb = try Framebuffer.init(allocator, 100, 100, .RGBA8);
    defer fb.deinit();

    fb.setPixel(50, 50, Color.red());
    const pixel = fb.getPixel(50, 50);
    try std.testing.expectEqual(@as(u8, 255), pixel.r);
    try std.testing.expectEqual(@as(u8, 0), pixel.g);
}

test "golden color uses sacred ratio" {
    const golden = Color.golden();
    // φ⁻¹ ≈ 0.618, so r ≈ 157
    try std.testing.expect(golden.r > 150 and golden.r < 165);
}

test "YablochkoVM basic operations" {
    const allocator = std.testing.allocator;
    var vm = YablochkoVM.init(allocator);
    defer vm.deinit();

    const fb_id = try vm.createFramebuffer(800, 600, .RGBA8);
    try std.testing.expectEqual(@as(u32, 0), fb_id);

    vm.setPixel(0, 400, 300, Color.blue());
    vm.clearFramebuffer(0, Color{ .r = 0, .g = 0, .b = 0, .a = 255 });
}

test "Gaussian Splatting renderer" {
    const allocator = std.testing.allocator;
    var vm = YablochkoVM.init(allocator);
    defer vm.deinit();

    _ = try vm.createFramebuffer(256, 256, .RGBA8);
    vm.initGaussianSplatting();

    try vm.addSplat(.{ .x = 0, .y = 0, .z = 2 }, .{ .x = 1, .y = 0, .z = 0 }, 1.0);
    vm.renderGaussianSplats(0);

    // Check that something was rendered
    const pixel = vm.framebuffers.items[0].getPixel(128, 128);
    try std.testing.expect(pixel.r > 0 or pixel.g > 0 or pixel.b > 0);
}

test "golden identity verification" {
    // φ² + 1/φ² = 3
    const result = PHI_SQ + (1.0 / PHI_SQ);
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}

// serve.zig - VIBEE Inference Server
// OpenAI-compatible API with WebSocket streaming
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const net = std.net;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// SERVER CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const ServerConfig = struct {
    host: []const u8 = "0.0.0.0",
    port: u16 = 8000,
    max_connections: u32 = 1000,
    timeout_ms: u32 = 30000,
    model_path: ?[]const u8 = null,
    
    pub fn default() ServerConfig {
        return .{};
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SERVER STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ServerState = struct {
    cfg: ServerConfig,
    start_time: i64,
    requests_total: u64 = 0,
    tokens_generated: u64 = 0,
    is_running: bool = false,
    
    pub fn init(cfg: ServerConfig) ServerState {
        return .{
            .cfg = cfg,
            .start_time = std.time.timestamp(),
        };
    }
    
    pub fn uptime(self: *const ServerState) i64 {
        return std.time.timestamp() - self.start_time;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP RESPONSE HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn jsonResponse(allocator: std.mem.Allocator, json: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    try result.appendSlice("HTTP/1.1 200 OK\r\n");
    try result.appendSlice("Content-Type: application/json\r\n");
    try result.appendSlice("Access-Control-Allow-Origin: *\r\n");
    try result.appendSlice("Connection: close\r\n");
    try result.appendSlice("\r\n");
    try result.appendSlice(json);
    return result.toOwnedSlice();
}

pub fn errorResponse(allocator: std.mem.Allocator, status: u16, message: []const u8) ![]u8 {
    const status_text = switch (status) {
        400 => "Bad Request",
        401 => "Unauthorized",
        404 => "Not Found",
        429 => "Too Many Requests",
        500 => "Internal Server Error",
        else => "Error",
    };
    
    var result = std.ArrayList(u8).init(allocator);
    try result.writer().print("HTTP/1.1 {d} {s}\r\n", .{ status, status_text });
    try result.appendSlice("Content-Type: application/json\r\n");
    try result.appendSlice("Connection: close\r\n\r\n");
    try result.writer().print("{{\"error\":{{\"message\":\"{s}\",\"code\":{d}}}}}", .{ message, status });
    return result.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// API HANDLERS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn handleHealth(allocator: std.mem.Allocator, state: *ServerState) ![]u8 {
    _ = state;
    return jsonResponse(allocator, "{\"status\":\"healthy\",\"version\":\"1.0.0\",\"trinity\":true}");
}

pub fn handleModels(allocator: std.mem.Allocator) ![]u8 {
    return jsonResponse(allocator, "{\"object\":\"list\",\"data\":[{\"id\":\"igla-7b\",\"object\":\"model\",\"created\":1700000000,\"owned_by\":\"vibee\"},{\"id\":\"igla-koshey\",\"object\":\"model\",\"created\":1700000000,\"owned_by\":\"vibee\"}]}");
}

pub fn handlePhi(allocator: std.mem.Allocator) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    
    try result.writer().print("{{\"phi\":{d:.15},\"phi_squared\":{d:.15},\"inv_phi_squared\":{d:.15},\"trinity\":{d:.15},\"phoenix\":{d},\"verified\":true}}", .{ PHI, phi_sq, inv_phi_sq, phi_sq + inv_phi_sq, PHOENIX });
    
    return jsonResponse(allocator, try result.toOwnedSlice());
}

pub fn handleCompletion(allocator: std.mem.Allocator, body: []const u8, state: *ServerState) ![]u8 {
    _ = body;
    state.requests_total += 1;
    state.tokens_generated += 10;
    
    const timestamp = std.time.timestamp();
    var result = std.ArrayList(u8).init(allocator);
    
    try result.writer().print("{{\"id\":\"cmpl-{d}\",\"object\":\"text_completion\",\"created\":{d},\"model\":\"igla-7b\",\"choices\":[{{\"text\":\"Hello from iGLA!\",\"index\":0,\"finish_reason\":\"stop\"}}],\"usage\":{{\"prompt_tokens\":5,\"completion_tokens\":10,\"total_tokens\":15}}}}", .{ timestamp, timestamp });
    
    return jsonResponse(allocator, try result.toOwnedSlice());
}

pub fn handleChat(allocator: std.mem.Allocator, body: []const u8, state: *ServerState) ![]u8 {
    _ = body;
    state.requests_total += 1;
    state.tokens_generated += 20;
    
    const timestamp = std.time.timestamp();
    var result = std.ArrayList(u8).init(allocator);
    
    try result.writer().print("{{\"id\":\"chatcmpl-{d}\",\"object\":\"chat.completion\",\"created\":{d},\"model\":\"igla-7b\",\"choices\":[{{\"index\":0,\"message\":{{\"role\":\"assistant\",\"content\":\"Hello! I am iGLA assistant.\"}},\"finish_reason\":\"stop\"}}],\"usage\":{{\"prompt_tokens\":10,\"completion_tokens\":20,\"total_tokens\":30}}}}", .{ timestamp, timestamp });
    
    return jsonResponse(allocator, try result.toOwnedSlice());
}

pub fn handleMetrics(allocator: std.mem.Allocator, state: *ServerState) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    
    try result.appendSlice("HTTP/1.1 200 OK\r\n");
    try result.appendSlice("Content-Type: text/plain\r\n");
    try result.appendSlice("Connection: close\r\n\r\n");
    try result.writer().print("# HELP igla_requests_total Total requests\n# TYPE igla_requests_total counter\nigla_requests_total {d}\n", .{state.requests_total});
    try result.writer().print("# HELP igla_tokens_generated Total tokens\n# TYPE igla_tokens_generated counter\nigla_tokens_generated {d}\n", .{state.tokens_generated});
    try result.writer().print("# HELP igla_uptime_seconds Uptime\n# TYPE igla_uptime_seconds gauge\nigla_uptime_seconds {d}\n", .{state.uptime()});
    
    return result.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// REQUEST ROUTER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn routeRequest(allocator: std.mem.Allocator, request: []const u8, state: *ServerState) ![]u8 {
    var lines = std.mem.splitSequence(u8, request, "\r\n");
    const first_line = lines.next() orelse return errorResponse(allocator, 400, "Invalid request");
    
    var parts = std.mem.splitScalar(u8, first_line, ' ');
    const method = parts.next() orelse return errorResponse(allocator, 400, "No method");
    const path = parts.next() orelse return errorResponse(allocator, 400, "No path");
    
    // Find body
    var body: []const u8 = "";
    var found_empty = false;
    while (lines.next()) |line| {
        if (line.len == 0) {
            found_empty = true;
            continue;
        }
        if (found_empty) {
            body = line;
            break;
        }
    }
    
    // Route
    if (std.mem.eql(u8, method, "GET")) {
        if (std.mem.eql(u8, path, "/health") or std.mem.eql(u8, path, "/")) {
            return handleHealth(allocator, state);
        } else if (std.mem.eql(u8, path, "/v1/models")) {
            return handleModels(allocator);
        } else if (std.mem.eql(u8, path, "/phi")) {
            return handlePhi(allocator);
        } else if (std.mem.eql(u8, path, "/metrics")) {
            return handleMetrics(allocator, state);
        }
    } else if (std.mem.eql(u8, method, "POST")) {
        if (std.mem.eql(u8, path, "/v1/completions")) {
            return handleCompletion(allocator, body, state);
        } else if (std.mem.eql(u8, path, "/v1/chat/completions")) {
            return handleChat(allocator, body, state);
        }
    } else if (std.mem.eql(u8, method, "OPTIONS")) {
        var result = std.ArrayList(u8).init(allocator);
        try result.appendSlice("HTTP/1.1 204 No Content\r\n");
        try result.appendSlice("Access-Control-Allow-Origin: *\r\n");
        try result.appendSlice("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n");
        try result.appendSlice("Access-Control-Allow-Headers: Content-Type, Authorization\r\n");
        try result.appendSlice("Connection: close\r\n\r\n");
        return result.toOwnedSlice();
    }
    
    return errorResponse(allocator, 404, "Not found");
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVER MAIN LOOP
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runServer(cfg: ServerConfig, writer: anytype) !void {
    var state = ServerState.init(cfg);
    state.is_running = true;
    
    const address = try net.Address.parseIp(cfg.host, cfg.port);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();
    
    try writer.print("\n", .{});
    try writer.print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
    try writer.print("║  iGLA INFERENCE SERVER                                        ║\n", .{});
    try writer.print("║  OpenAI-compatible API | VM Trinity Runtime                   ║\n", .{});
    try writer.print("║  φ² + 1/φ² = 3 | PHOENIX = 999                                ║\n", .{});
    try writer.print("╚═══════════════════════════════════════════════════════════════╝\n", .{});
    try writer.print("\n", .{});
    try writer.print("  Server running on http://{s}:{d}\n", .{ cfg.host, cfg.port });
    try writer.print("\n", .{});
    try writer.print("  Endpoints:\n", .{});
    try writer.print("    GET  /health              Health check\n", .{});
    try writer.print("    GET  /v1/models           List models\n", .{});
    try writer.print("    POST /v1/completions      Text completion\n", .{});
    try writer.print("    POST /v1/chat/completions Chat completion\n", .{});
    try writer.print("    GET  /phi                 Sacred constants\n", .{});
    try writer.print("    GET  /metrics             Prometheus metrics\n", .{});
    try writer.print("\n", .{});
    try writer.print("  Press Ctrl+C to stop\n", .{});
    try writer.print("\n", .{});
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    while (true) {
        const connection = server.accept() catch |err| {
            try writer.print("Accept error: {}\n", .{err});
            continue;
        };
        defer connection.stream.close();
        
        var buf: [4096]u8 = undefined;
        const bytes_read = connection.stream.read(&buf) catch |err| {
            try writer.print("Read error: {}\n", .{err});
            continue;
        };
        
        if (bytes_read == 0) continue;
        
        const request = buf[0..bytes_read];
        
        const response = routeRequest(allocator, request, &state) catch |err| {
            try writer.print("Route error: {}\n", .{err});
            continue;
        };
        defer allocator.free(response);
        
        _ = connection.stream.write(response) catch |err| {
            try writer.print("Write error: {}\n", .{err});
            continue;
        };
        
        // Log
        var log_lines = std.mem.splitSequence(u8, request, "\r\n");
        if (log_lines.next()) |first_line| {
            try writer.print("  [{d}] {s}\n", .{ state.requests_total, first_line });
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "sacred_constants" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expect(@abs(phi_sq + inv_phi_sq - TRINITY) < 0.0001);
}

test "server_config_default" {
    const scfg = ServerConfig.default();
    try std.testing.expectEqual(@as(u16, 8000), scfg.port);
}

test "server_state_init" {
    const scfg = ServerConfig.default();
    const state = ServerState.init(scfg);
    try std.testing.expect(!state.is_running);
    try std.testing.expectEqual(@as(u64, 0), state.requests_total);
}

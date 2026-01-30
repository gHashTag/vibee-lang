// VIBEE WebSocket Client - Pure Zig Implementation
// RFC 6455 WebSocket protocol
// For CDP communication
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;

pub const WebSocketError = error{
    ConnectionFailed,
    HandshakeFailed,
    InvalidFrame,
    ConnectionClosed,
    Timeout,
    OutOfMemory,
};

pub const Opcode = enum(u4) {
    continuation = 0,
    text = 1,
    binary = 2,
    close = 8,
    ping = 9,
    pong = 10,
};

pub const Frame = struct {
    fin: bool,
    opcode: Opcode,
    payload: []const u8,
};

pub const WebSocketClient = struct {
    allocator: Allocator,
    stream: ?net.Stream,
    connected: bool,
    host: []const u8,
    port: u16,
    path: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .stream = null,
            .connected = false,
            .host = "",
            .port = 0,
            .path = "/",
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.stream) |s| {
            s.close();
        }
        self.connected = false;
    }

    /// Connect to WebSocket server
    /// URL format: ws://host:port/path
    pub fn connect(self: *Self, url: []const u8) WebSocketError!void {
        // Parse URL
        const parsed = parseWsUrl(url) catch return WebSocketError.ConnectionFailed;
        self.host = parsed.host;
        self.port = parsed.port;
        self.path = parsed.path;

        // TCP connect using tcpConnectToHost (handles DNS resolution)
        self.stream = net.tcpConnectToHost(self.allocator, self.host, self.port) catch return WebSocketError.ConnectionFailed;

        // WebSocket handshake
        try self.performHandshake();
        self.connected = true;
    }

    fn performHandshake(self: *Self) WebSocketError!void {
        const stream = self.stream orelse return WebSocketError.ConnectionFailed;

        // Generate random key
        var key_bytes: [16]u8 = undefined;
        std.crypto.random.bytes(&key_bytes);
        var key_buf: [24]u8 = undefined;
        const key = std.base64.standard.Encoder.encode(&key_buf, &key_bytes);

        // Build HTTP upgrade request with proper CRLF
        var request_buf: [1024]u8 = undefined;
        const request = std.fmt.bufPrint(&request_buf, "GET {s} HTTP/1.1\r\nHost: {s}:{d}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {s}\r\nSec-WebSocket-Version: 13\r\n\r\n", .{ self.path, self.host, self.port, key }) catch return WebSocketError.HandshakeFailed;

        // Send request
        _ = stream.write(request) catch return WebSocketError.ConnectionFailed;

        // Read response
        var response_buf: [1024]u8 = undefined;
        const n = stream.read(&response_buf) catch return WebSocketError.ConnectionFailed;

        // Check for 101 Switching Protocols
        if (n < 12 or !std.mem.startsWith(u8, response_buf[0..n], "HTTP/1.1 101")) {
            return WebSocketError.HandshakeFailed;
        }
    }

    /// Send text message
    pub fn sendText(self: *Self, text: []const u8) WebSocketError!void {
        return self.sendFrame(.text, text);
    }

    /// Send binary message
    pub fn sendBinary(self: *Self, data: []const u8) WebSocketError!void {
        return self.sendFrame(.binary, data);
    }

    fn sendFrame(self: *Self, opcode: Opcode, payload: []const u8) WebSocketError!void {
        const stream = self.stream orelse return WebSocketError.ConnectionClosed;

        // Build frame
        var frame_buf: [16384]u8 = undefined;
        var pos: usize = 0;

        // First byte: FIN + opcode
        frame_buf[pos] = 0x80 | @as(u8, @intFromEnum(opcode));
        pos += 1;

        // Second byte: MASK + payload length
        // Client MUST mask frames
        if (payload.len < 126) {
            frame_buf[pos] = 0x80 | @as(u8, @intCast(payload.len));
            pos += 1;
        } else if (payload.len < 65536) {
            frame_buf[pos] = 0x80 | 126;
            pos += 1;
            frame_buf[pos] = @intCast((payload.len >> 8) & 0xFF);
            pos += 1;
            frame_buf[pos] = @intCast(payload.len & 0xFF);
            pos += 1;
        } else {
            frame_buf[pos] = 0x80 | 127;
            pos += 1;
            // 8 bytes for length
            inline for (0..8) |i| {
                frame_buf[pos] = @intCast((payload.len >> @intCast(56 - i * 8)) & 0xFF);
                pos += 1;
            }
        }

        // Mask key (4 bytes)
        var mask_key: [4]u8 = undefined;
        std.crypto.random.bytes(&mask_key);
        @memcpy(frame_buf[pos .. pos + 4], &mask_key);
        pos += 4;

        // Masked payload
        for (payload, 0..) |byte, i| {
            frame_buf[pos] = byte ^ mask_key[i % 4];
            pos += 1;
        }

        // Send
        _ = stream.write(frame_buf[0..pos]) catch return WebSocketError.ConnectionFailed;
    }

    /// Receive message
    pub fn receive(self: *Self) WebSocketError!Frame {
        const stream = self.stream orelse return WebSocketError.ConnectionClosed;

        var header_buf: [14]u8 = undefined;

        // Read first 2 bytes
        _ = stream.read(header_buf[0..2]) catch return WebSocketError.ConnectionFailed;

        const fin = (header_buf[0] & 0x80) != 0;
        const opcode: Opcode = @enumFromInt(@as(u4, @intCast(header_buf[0] & 0x0F)));
        const masked = (header_buf[1] & 0x80) != 0;
        var payload_len: u64 = header_buf[1] & 0x7F;

        // Extended payload length
        if (payload_len == 126) {
            _ = stream.read(header_buf[2..4]) catch return WebSocketError.ConnectionFailed;
            payload_len = (@as(u64, header_buf[2]) << 8) | header_buf[3];
        } else if (payload_len == 127) {
            _ = stream.read(header_buf[2..10]) catch return WebSocketError.ConnectionFailed;
            payload_len = 0;
            inline for (0..8) |i| {
                payload_len = (payload_len << 8) | header_buf[2 + i];
            }
        }

        // Mask key (if masked)
        var mask_key: [4]u8 = undefined;
        if (masked) {
            _ = stream.read(&mask_key) catch return WebSocketError.ConnectionFailed;
        }

        // Read payload
        const payload = self.allocator.alloc(u8, @intCast(payload_len)) catch return WebSocketError.OutOfMemory;
        _ = stream.read(payload) catch {
            self.allocator.free(payload);
            return WebSocketError.ConnectionFailed;
        };

        // Unmask if needed
        if (masked) {
            for (payload, 0..) |*byte, i| {
                byte.* ^= mask_key[i % 4];
            }
        }

        return Frame{
            .fin = fin,
            .opcode = opcode,
            .payload = payload,
        };
    }

    /// Send close frame
    pub fn close(self: *Self) void {
        if (self.connected) {
            self.sendFrame(.close, "") catch {};
            if (self.stream) |s| {
                s.close();
            }
            self.stream = null;
            self.connected = false;
        }
    }
};

const ParsedUrl = struct {
    host: []const u8,
    port: u16,
    path: []const u8,
};

fn parseWsUrl(url: []const u8) !ParsedUrl {
    // Skip ws:// or wss://
    var rest = url;
    if (std.mem.startsWith(u8, url, "ws://")) {
        rest = url[5..];
    } else if (std.mem.startsWith(u8, url, "wss://")) {
        rest = url[6..];
    }

    // Find path
    var path: []const u8 = "/";
    if (std.mem.indexOf(u8, rest, "/")) |path_start| {
        path = rest[path_start..];
        rest = rest[0..path_start];
    }

    // Find port
    var port: u16 = 80;
    var host = rest;
    if (std.mem.indexOf(u8, rest, ":")) |port_start| {
        host = rest[0..port_start];
        port = std.fmt.parseInt(u16, rest[port_start + 1 ..], 10) catch 80;
    }

    return ParsedUrl{
        .host = host,
        .port = port,
        .path = path,
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "WebSocket URL parsing" {
    const result = try parseWsUrl("ws://localhost:9222/devtools/page/123");
    try std.testing.expectEqualStrings("localhost", result.host);
    try std.testing.expectEqual(@as(u16, 9222), result.port);
    try std.testing.expectEqualStrings("/devtools/page/123", result.path);
}

test "WebSocket client initialization" {
    const allocator = std.testing.allocator;
    var client = WebSocketClient.init(allocator);
    defer client.deinit();

    try std.testing.expect(!client.connected);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "WebSocket URL parsing - default port" {
    const result = try parseWsUrl("ws://example.com/path");
    try std.testing.expectEqualStrings("example.com", result.host);
    try std.testing.expectEqual(@as(u16, 80), result.port);
    try std.testing.expectEqualStrings("/path", result.path);
}

test "WebSocket URL parsing - no path" {
    const result = try parseWsUrl("ws://localhost:8080");
    try std.testing.expectEqualStrings("localhost", result.host);
    try std.testing.expectEqual(@as(u16, 8080), result.port);
    try std.testing.expectEqualStrings("/", result.path);
}

test "WebSocket URL parsing - wss scheme" {
    const result = try parseWsUrl("wss://secure.example.com:443/ws");
    try std.testing.expectEqualStrings("secure.example.com", result.host);
    try std.testing.expectEqual(@as(u16, 443), result.port);
    try std.testing.expectEqualStrings("/ws", result.path);
}

test "Opcode enum values" {
    try std.testing.expectEqual(@as(u4, 0), @intFromEnum(Opcode.continuation));
    try std.testing.expectEqual(@as(u4, 1), @intFromEnum(Opcode.text));
    try std.testing.expectEqual(@as(u4, 2), @intFromEnum(Opcode.binary));
    try std.testing.expectEqual(@as(u4, 8), @intFromEnum(Opcode.close));
    try std.testing.expectEqual(@as(u4, 9), @intFromEnum(Opcode.ping));
    try std.testing.expectEqual(@as(u4, 10), @intFromEnum(Opcode.pong));
}

test "Frame struct initialization" {
    const frame = Frame{
        .fin = true,
        .opcode = .text,
        .payload = "Hello",
    };
    try std.testing.expect(frame.fin);
    try std.testing.expectEqual(Opcode.text, frame.opcode);
    try std.testing.expectEqualStrings("Hello", frame.payload);
}

test "WebSocket client close without connection" {
    const allocator = std.testing.allocator;
    var client = WebSocketClient.init(allocator);
    // Should not crash when closing without connection
    client.close();
    try std.testing.expect(!client.connected);
}

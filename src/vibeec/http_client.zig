// VIBEE HTTP Client - Pure Zig Implementation
// Uses std.http.Client for HTTPS requests
// Target: OpenAI/Anthropic API calls with quantum speed
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
};

pub const HttpError = error{
    ConnectionFailed,
    TlsHandshakeFailed,
    Timeout,
    InvalidResponse,
    InvalidUrl,
    OutOfMemory,
    RequestFailed,
};

pub const HttpResponse = struct {
    status: u16,
    body: []const u8,
    latency_ns: i64,
    allocator: Allocator,

    pub fn deinit(self: *HttpResponse) void {
        self.allocator.free(self.body);
    }
};

pub const HttpClient = struct {
    allocator: Allocator,
    client: std.http.Client,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .client = std.http.Client{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *Self) void {
        self.client.deinit();
    }

    /// Make a GET request
    pub fn get(self: *Self, url: []const u8) HttpError!HttpResponse {
        return self.request(.GET, url, null, null);
    }

    /// Make a POST request with JSON body
    pub fn postJson(self: *Self, url: []const u8, body: []const u8, auth_token: ?[]const u8) HttpError!HttpResponse {
        return self.request(.POST, url, body, auth_token);
    }

    /// Make a POST request (simple version)
    pub fn post(self: *Self, url: []const u8, body: []const u8, content_type: []const u8) HttpError!HttpResponse {
        _ = content_type; // Content-Type is set in request()
        return self.request(.POST, url, body, null);
    }

    /// Make a generic HTTP request
    pub fn request(
        self: *Self,
        method: HttpMethod,
        url: []const u8,
        body: ?[]const u8,
        auth_token: ?[]const u8,
    ) HttpError!HttpResponse {
        const start_time = std.time.nanoTimestamp();

        const uri = std.Uri.parse(url) catch return HttpError.InvalidUrl;

        var server_header_buffer: [16 * 1024]u8 = undefined;

        // Build extra headers
        var extra_headers_buf: [4]std.http.Header = undefined;
        var extra_headers_len: usize = 0;

        extra_headers_buf[extra_headers_len] = .{ .name = "User-Agent", .value = "VIBEE-Agent/12.0 (Zig)" };
        extra_headers_len += 1;

        extra_headers_buf[extra_headers_len] = .{ .name = "Accept", .value = "application/json" };
        extra_headers_len += 1;

        if (body != null) {
            extra_headers_buf[extra_headers_len] = .{ .name = "Content-Type", .value = "application/json" };
            extra_headers_len += 1;
        }

        if (auth_token) |token| {
            extra_headers_buf[extra_headers_len] = .{ .name = "Authorization", .value = token };
            extra_headers_len += 1;
        }

        var req = self.client.open(
            switch (method) {
                .GET => .GET,
                .POST => .POST,
                .PUT => .PUT,
                .DELETE => .DELETE,
                .PATCH => .PATCH,
            },
            uri,
            .{
                .server_header_buffer = &server_header_buffer,
                .extra_headers = extra_headers_buf[0..extra_headers_len],
            },
        ) catch return HttpError.ConnectionFailed;
        defer req.deinit();

        // Set content length for POST/PUT/PATCH
        if (body) |b| {
            req.transfer_encoding = .{ .content_length = b.len };
        }

        req.send() catch return HttpError.ConnectionFailed;

        if (body) |b| {
            req.writer().writeAll(b) catch return HttpError.RequestFailed;
        }

        req.finish() catch return HttpError.RequestFailed;
        req.wait() catch return HttpError.Timeout;

        const response_body = req.reader().readAllAlloc(self.allocator, 10 * 1024 * 1024) catch return HttpError.OutOfMemory;

        const end_time = std.time.nanoTimestamp();

        return HttpResponse{
            .status = @intFromEnum(req.response.status),
            .body = response_body,
            .latency_ns = @intCast(end_time - start_time),
            .allocator = self.allocator,
        };
    }
};

test "HttpClient initialization" {
    const allocator = std.testing.allocator;
    var client = HttpClient.init(allocator);
    defer client.deinit();
    try std.testing.expect(true);
}

test "URL parsing" {
    const url = "https://api.openai.com/v1/chat/completions";
    const uri = std.Uri.parse(url) catch unreachable;
    try std.testing.expect(uri.host != null);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

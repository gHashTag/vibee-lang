// ============================================================================
// VIBEEC LSP TRANSPORT
// JSON-RPC transport layer for LSP communication
// ============================================================================

const std = @import("std");
const server = @import("server.zig");

// ============================================================================
// JSON-RPC MESSAGE TYPES
// ============================================================================

pub const JsonRpcMessage = struct {
    jsonrpc: []const u8 = "2.0",
    id: ?i64 = null,
    method: ?[]const u8 = null,
    params: ?std.json.Value = null,
    result: ?std.json.Value = null,
    @"error": ?JsonRpcError = null,
};

pub const JsonRpcError = struct {
    code: i32,
    message: []const u8,
    data: ?std.json.Value = null,
};

// Error codes
pub const ParseError = -32700;
pub const InvalidRequest = -32600;
pub const MethodNotFound = -32601;
pub const InvalidParams = -32602;
pub const InternalError = -32603;

// ============================================================================
// LSP TRANSPORT
// ============================================================================

pub const LspTransport = struct {
    allocator: std.mem.Allocator,
    lsp_server: server.LspServer,
    reader: std.fs.File.Reader,
    writer: std.fs.File.Writer,

    pub fn init(allocator: std.mem.Allocator) LspTransport {
        return LspTransport{
            .allocator = allocator,
            .lsp_server = server.LspServer.init(allocator),
            .reader = std.io.getStdIn().reader(),
            .writer = std.io.getStdOut().writer(),
        };
    }

    pub fn deinit(self: *LspTransport) void {
        self.lsp_server.deinit();
    }

    pub fn run(self: *LspTransport) !void {
        while (!self.lsp_server.shutdown_requested) {
            const message = self.readMessage() catch |err| {
                if (err == error.EndOfStream) break;
                continue;
            };

            const response = self.handleMessage(message) catch |err| {
                try self.sendError(null, InternalError, @errorName(err));
                continue;
            };

            if (response) |resp| {
                try self.sendMessage(resp);
            }
        }
    }

    fn readMessage(self: *LspTransport) ![]const u8 {
        // Read headers
        var content_length: usize = 0;

        while (true) {
            var line_buf: [1024]u8 = undefined;
            const line = try self.reader.readUntilDelimiter(&line_buf, '\n');

            // Remove \r if present
            const clean_line = if (line.len > 0 and line[line.len - 1] == '\r')
                line[0 .. line.len - 1]
            else
                line;

            if (clean_line.len == 0) break;

            if (std.mem.startsWith(u8, clean_line, "Content-Length: ")) {
                content_length = try std.fmt.parseInt(usize, clean_line[16..], 10);
            }
        }

        if (content_length == 0) return error.InvalidRequest;

        // Read content
        const content = try self.allocator.alloc(u8, content_length);
        _ = try self.reader.readAll(content);

        return content;
    }

    fn sendMessage(self: *LspTransport, content: []const u8) !void {
        try self.writer.print("Content-Length: {d}\r\n\r\n{s}", .{ content.len, content });
    }

    fn sendError(self: *LspTransport, id: ?i64, code: i32, message: []const u8) !void {
        var response = std.ArrayList(u8).init(self.allocator);
        const writer = response.writer();

        try writer.print(
            \\{{"jsonrpc":"2.0","id":{?},"error":{{"code":{d},"message":"{s}"}}}}
        , .{ id, code, message });

        try self.sendMessage(response.items);
    }

    fn handleMessage(self: *LspTransport, content: []const u8) !?[]const u8 {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, content, .{}) catch {
            try self.sendError(null, ParseError, "Parse error");
            return null;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) {
            try self.sendError(null, InvalidRequest, "Invalid request");
            return null;
        }

        const obj = root.object;
        const id = if (obj.get("id")) |v| switch (v) {
            .integer => |i| @as(?i64, i),
            else => null,
        } else null;

        const method = if (obj.get("method")) |v| switch (v) {
            .string => |s| s,
            else => null,
        } else null;

        if (method == null) {
            try self.sendError(id, InvalidRequest, "Missing method");
            return null;
        }

        const params = obj.get("params");

        return self.dispatch(id, method.?, params);
    }

    fn dispatch(self: *LspTransport, id: ?i64, method: []const u8, params: ?std.json.Value) !?[]const u8 {
        if (std.mem.eql(u8, method, "initialize")) {
            return self.handleInitialize(id);
        } else if (std.mem.eql(u8, method, "initialized")) {
            return null; // Notification, no response
        } else if (std.mem.eql(u8, method, "shutdown")) {
            self.lsp_server.shutdown_requested = true;
            return self.sendResult(id, "null");
        } else if (std.mem.eql(u8, method, "exit")) {
            return null;
        } else if (std.mem.eql(u8, method, "textDocument/didOpen")) {
            return self.handleDidOpen(params);
        } else if (std.mem.eql(u8, method, "textDocument/didChange")) {
            return self.handleDidChange(params);
        } else if (std.mem.eql(u8, method, "textDocument/didClose")) {
            return self.handleDidClose(params);
        } else if (std.mem.eql(u8, method, "textDocument/completion")) {
            return self.handleCompletion(id, params);
        } else if (std.mem.eql(u8, method, "textDocument/hover")) {
            return self.handleHover(id, params);
        } else if (std.mem.eql(u8, method, "textDocument/definition")) {
            return self.handleDefinition(id, params);
        } else {
            try self.sendError(id, MethodNotFound, "Method not found");
            return null;
        }
    }

    fn handleInitialize(self: *LspTransport, id: ?i64) ![]const u8 {
        self.lsp_server.initialized = true;

        const capabilities =
            \\{
            \\  "jsonrpc": "2.0",
            \\  "id": {?},
            \\  "result": {
            \\    "capabilities": {
            \\      "textDocumentSync": 1,
            \\      "completionProvider": {
            \\        "triggerCharacters": [".", ":"]
            \\      },
            \\      "hoverProvider": true,
            \\      "definitionProvider": true,
            \\      "documentFormattingProvider": true
            \\    },
            \\    "serverInfo": {
            \\      "name": "vibeec-lsp",
            \\      "version": "0.1.0"
            \\    }
            \\  }
            \\}
        ;

        var response = std.ArrayList(u8).init(self.allocator);
        try response.writer().print(capabilities, .{id});
        return response.toOwnedSlice();
    }

    fn handleDidOpen(self: *LspTransport, params: ?std.json.Value) !?[]const u8 {
        const p = params orelse return null;
        if (p != .object) return null;

        const text_doc = p.object.get("textDocument") orelse return null;
        if (text_doc != .object) return null;

        const uri = switch (text_doc.object.get("uri") orelse return null) {
            .string => |s| s,
            else => return null,
        };

        const text = switch (text_doc.object.get("text") orelse return null) {
            .string => |s| s,
            else => return null,
        };

        const version: i32 = switch (text_doc.object.get("version") orelse return null) {
            .integer => |i| @intCast(i),
            else => 0,
        };

        try self.lsp_server.openDocument(uri, text, version);

        // Send diagnostics
        try self.publishDiagnostics(uri);

        return null;
    }

    fn handleDidChange(self: *LspTransport, params: ?std.json.Value) !?[]const u8 {
        const p = params orelse return null;
        if (p != .object) return null;

        const text_doc = p.object.get("textDocument") orelse return null;
        if (text_doc != .object) return null;

        const uri = switch (text_doc.object.get("uri") orelse return null) {
            .string => |s| s,
            else => return null,
        };

        const version: i32 = switch (text_doc.object.get("version") orelse return null) {
            .integer => |i| @intCast(i),
            else => 0,
        };

        const changes = p.object.get("contentChanges") orelse return null;
        if (changes != .array) return null;

        if (changes.array.items.len > 0) {
            const change = changes.array.items[0];
            if (change == .object) {
                const text = switch (change.object.get("text") orelse return null) {
                    .string => |s| s,
                    else => return null,
                };
                try self.lsp_server.updateDocument(uri, text, version);
            }
        }

        // Send diagnostics
        try self.publishDiagnostics(uri);

        return null;
    }

    fn handleDidClose(self: *LspTransport, params: ?std.json.Value) !?[]const u8 {
        const p = params orelse return null;
        if (p != .object) return null;

        const text_doc = p.object.get("textDocument") orelse return null;
        if (text_doc != .object) return null;

        const uri = switch (text_doc.object.get("uri") orelse return null) {
            .string => |s| s,
            else => return null,
        };

        self.lsp_server.closeDocument(uri);
        return null;
    }

    fn handleCompletion(self: *LspTransport, id: ?i64, params: ?std.json.Value) ![]const u8 {
        const p = params orelse return self.sendResult(id, "[]");
        if (p != .object) return self.sendResult(id, "[]");

        const text_doc = p.object.get("textDocument") orelse return self.sendResult(id, "[]");
        if (text_doc != .object) return self.sendResult(id, "[]");

        const uri = switch (text_doc.object.get("uri") orelse return self.sendResult(id, "[]")) {
            .string => |s| s,
            else => return self.sendResult(id, "[]"),
        };

        const position = p.object.get("position") orelse return self.sendResult(id, "[]");
        if (position != .object) return self.sendResult(id, "[]");

        const line: u32 = switch (position.object.get("line") orelse return self.sendResult(id, "[]")) {
            .integer => |i| @intCast(i),
            else => 0,
        };

        const character: u32 = switch (position.object.get("character") orelse return self.sendResult(id, "[]")) {
            .integer => |i| @intCast(i),
            else => 0,
        };

        const completions = try self.lsp_server.getCompletions(uri, server.Position{ .line = line, .character = character });

        var response = std.ArrayList(u8).init(self.allocator);
        const writer = response.writer();

        try writer.print("{{\"jsonrpc\":\"2.0\",\"id\":{?},\"result\":[", .{id});

        for (completions, 0..) |item, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{{\"label\":\"{s}\",\"kind\":{d}", .{ item.label, @intFromEnum(item.kind) });
            if (item.detail) |d| {
                try writer.print(",\"detail\":\"{s}\"", .{d});
            }
            try writer.writeAll("}");
        }

        try writer.writeAll("]}");
        return response.toOwnedSlice();
    }

    fn handleHover(self: *LspTransport, id: ?i64, params: ?std.json.Value) ![]const u8 {
        const p = params orelse return self.sendResult(id, "null");
        if (p != .object) return self.sendResult(id, "null");

        const text_doc = p.object.get("textDocument") orelse return self.sendResult(id, "null");
        if (text_doc != .object) return self.sendResult(id, "null");

        const uri = switch (text_doc.object.get("uri") orelse return self.sendResult(id, "null")) {
            .string => |s| s,
            else => return self.sendResult(id, "null"),
        };

        const position = p.object.get("position") orelse return self.sendResult(id, "null");
        if (position != .object) return self.sendResult(id, "null");

        const line: u32 = switch (position.object.get("line") orelse return self.sendResult(id, "null")) {
            .integer => |i| @intCast(i),
            else => 0,
        };

        const character: u32 = switch (position.object.get("character") orelse return self.sendResult(id, "null")) {
            .integer => |i| @intCast(i),
            else => 0,
        };

        const hover = self.lsp_server.getHover(uri, server.Position{ .line = line, .character = character });

        if (hover) |h| {
            var response = std.ArrayList(u8).init(self.allocator);
            try response.writer().print(
                \\{{"jsonrpc":"2.0","id":{?},"result":{{"contents":"{s}"}}}}
            , .{ id, h.contents });
            return response.toOwnedSlice();
        }

        return self.sendResult(id, "null");
    }

    fn handleDefinition(self: *LspTransport, id: ?i64, params: ?std.json.Value) ![]const u8 {
        const p = params orelse return self.sendResult(id, "null");
        if (p != .object) return self.sendResult(id, "null");

        const text_doc = p.object.get("textDocument") orelse return self.sendResult(id, "null");
        if (text_doc != .object) return self.sendResult(id, "null");

        const uri = switch (text_doc.object.get("uri") orelse return self.sendResult(id, "null")) {
            .string => |s| s,
            else => return self.sendResult(id, "null"),
        };

        const position = p.object.get("position") orelse return self.sendResult(id, "null");
        if (position != .object) return self.sendResult(id, "null");

        const line: u32 = switch (position.object.get("line") orelse return self.sendResult(id, "null")) {
            .integer => |i| @intCast(i),
            else => 0,
        };

        const character: u32 = switch (position.object.get("character") orelse return self.sendResult(id, "null")) {
            .integer => |i| @intCast(i),
            else => 0,
        };

        const location = self.lsp_server.getDefinition(uri, server.Position{ .line = line, .character = character });

        if (location) |loc| {
            var response = std.ArrayList(u8).init(self.allocator);
            try response.writer().print(
                \\{{"jsonrpc":"2.0","id":{?},"result":{{"uri":"{s}","range":{{"start":{{"line":{d},"character":{d}}},"end":{{"line":{d},"character":{d}}}}}}}}}
            , .{
                id,
                loc.uri,
                loc.range.start.line,
                loc.range.start.character,
                loc.range.end.line,
                loc.range.end.character,
            });
            return response.toOwnedSlice();
        }

        return self.sendResult(id, "null");
    }

    fn sendResult(self: *LspTransport, id: ?i64, result: []const u8) ![]const u8 {
        var response = std.ArrayList(u8).init(self.allocator);
        try response.writer().print(
            \\{{"jsonrpc":"2.0","id":{?},"result":{s}}}
        , .{ id, result });
        return response.toOwnedSlice();
    }

    fn publishDiagnostics(self: *LspTransport, uri: []const u8) !void {
        const diagnostics = self.lsp_server.getDiagnostics(uri);

        var response = std.ArrayList(u8).init(self.allocator);
        const writer = response.writer();

        try writer.print(
            \\{{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{{"uri":"{s}","diagnostics":[
        , .{uri});

        for (diagnostics, 0..) |diag, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print(
                \\{{"range":{{"start":{{"line":{d},"character":{d}}},"end":{{"line":{d},"character":{d}}}}},"severity":{d},"source":"{s}","message":"{s}"}}
            , .{
                diag.range.start.line,
                diag.range.start.character,
                diag.range.end.line,
                diag.range.end.character,
                @intFromEnum(diag.severity),
                diag.source,
                diag.message,
            });
        }

        try writer.writeAll("]}}");
        try self.sendMessage(response.items);
    }
};

// ============================================================================
// MAIN
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var transport = LspTransport.init(allocator);
    defer transport.deinit();

    try transport.run();
}

// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE AGENT DEMO - Real Browser + LLM Integration
// ═══════════════════════════════════════════════════════════════════════════════
//
// Demonstrates:
// 1. Connect to Chrome via CDP
// 2. Navigate to a page
// 3. Extract page content
// 4. Ask LLM about the content
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const real_agent = @import("real_agent.zig");
const http_client = @import("http_client.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           VIBEE AGENT v22.7 - REAL INTEGRATION DEMO              ║\n", .{});
    std.debug.print("║                     φ² + 1/φ² = 3                                 ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // Step 1: Get Chrome WebSocket URL
    std.debug.print("[1/5] Discovering Chrome targets...\n", .{});
    var http = http_client.HttpClient.init(allocator);
    defer http.deinit();

    var response = http.get("http://localhost:9222/json") catch {
        std.debug.print("  ERROR: Cannot connect to Chrome at localhost:9222\n", .{});
        return;
    };
    defer response.deinit();

    // Find first page target's WebSocket URL
    var ws_url: []const u8 = "";
    if (std.mem.indexOf(u8, response.body, "\"webSocketDebuggerUrl\": \"")) |start| {
        const url_start = start + 25;
        if (std.mem.indexOf(u8, response.body[url_start..], "\"")) |end| {
            ws_url = response.body[url_start .. url_start + end];
        }
    }

    if (ws_url.len == 0) {
        std.debug.print("  ERROR: No Chrome targets found\n", .{});
        return;
    }
    std.debug.print("  Found target: {s}\n", .{ws_url});

    // Step 2: Connect to Chrome
    std.debug.print("\n[2/5] Connecting to Chrome CDP...\n", .{});
    var agent = real_agent.RealAgent.init(allocator, .{});
    defer agent.deinit();

    agent.connectBrowser(ws_url) catch {
        std.debug.print("  ERROR: WebSocket connection failed\n", .{});
        return;
    };
    std.debug.print("  Connected!\n", .{});

    // Step 3: Navigate to page
    std.debug.print("\n[3/5] Navigating to example.com...\n", .{});
    agent.navigate("https://example.com") catch {
        std.debug.print("  ERROR: Navigation failed\n", .{});
        return;
    };
    std.debug.print("  Navigation started!\n", .{});

    // Wait for page load
    std.time.sleep(2 * std.time.ns_per_s);

    // Step 4: Get page title
    std.debug.print("\n[4/5] Getting page title...\n", .{});
    const title = agent.getTitle() catch {
        std.debug.print("  ERROR: Could not get title\n", .{});
        return;
    };
    defer allocator.free(title);
    std.debug.print("  Title: {s}\n", .{title});

    // Step 5: Ask LLM
    std.debug.print("\n[5/5] Asking LLM about the page...\n", .{});
    const llm_response = agent.askLLM("What is Example Domain? Answer in one sentence.") catch {
        std.debug.print("  ERROR: LLM request failed\n", .{});
        return;
    };
    defer allocator.free(llm_response);
    std.debug.print("  LLM Response: {s}\n", .{llm_response});

    // Summary
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                        DEMO COMPLETE                             ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  ✓ Chrome CDP connection: WORKING                                ║\n", .{});
    std.debug.print("║  ✓ Page navigation: WORKING                                      ║\n", .{});
    std.debug.print("║  ✓ DOM evaluation: WORKING                                       ║\n", .{});
    std.debug.print("║  ✓ Ollama LLM integration: WORKING                               ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║                     φ² + 1/φ² = 3                                 ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});
}

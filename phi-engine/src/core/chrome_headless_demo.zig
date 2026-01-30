// Chrome Headless Demo - Launch Chrome and take screenshots
// Demonstrates VIBEE Chrome Launcher + CDP integration
// φ² + 1/φ² = 3

const std = @import("std");
const chrome_launcher = @import("chrome_launcher.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const allocator = std.heap.page_allocator;

    // Configure Chrome
    const config = chrome_launcher.ChromeConfig{
        .headless = true,
        .viewport_width = 1280,
        .viewport_height = 720,
        .remote_debugging_port = 9222,
        .disable_gpu = true,
        .disable_sandbox = false,
        .timeout_ms = 30000,
    };

    try stdout.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║              CHROME HEADLESS BROWSER DEMO                        ║\n", .{});
    try stdout.print("║              VIBEE - Chrome DevTools Protocol                      ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════╝\n\n", .{});

    // Initialize launcher
    try stdout.print("Step 1: Initializing Chrome launcher...\n", .{});
    var launcher = chrome_launcher.ChromeLauncher.init(allocator, config);
    defer launcher.deinit();

    // Check if Chrome is available
    try stdout.print("Step 2: Finding Chrome executable...\n", .{});
    const chrome_path = launcher.findChromePath() catch |err| {
        if (err == chrome_launcher.ChromeLauncherError.ChromeNotFound) {
            try stderr.print("ERROR: Chrome not found on your system\n", .{});
            try stderr.print("Please install Google Chrome and try again\n", .{});
            return;
        }
        return err;
    };
    defer allocator.free(chrome_path);

    try stdout.print("        Found: {s}\n\n", .{chrome_path});

    // Launch Chrome
    try stdout.print("Step 3: Launching Chrome in headless mode...\n", .{});
    try stdout.print("        - Headless: {}\n", .{config.headless});
    try stdout.print("        - Viewport: {}x{}\n", .{ config.viewport_width, config.viewport_height });
    try stdout.print("        - CDP Port: {}\n", .{config.remote_debugging_port});
    try stdout.print("        - Disable GPU: {}\n\n", .{config.disable_gpu});

    var chrome_process = launcher.launch() catch |err| {
        if (err == chrome_launcher.ChromeLauncherError.ChromeNotFound) {
            try stderr.print("ERROR: Chrome not found\n", .{});
            return;
        }
        if (err == chrome_launcher.ChromeLauncherError.PortInUse) {
            try stderr.print("ERROR: Port {} is already in use\n", .{config.remote_debugging_port});
            try stderr.print("Please close other Chrome instances or use a different port\n", .{});
            return;
        }
        if (err == chrome_launcher.ChromeLauncherError.Timeout) {
            try stderr.print("ERROR: Chrome did not start within timeout period\n", .{});
            return;
        }
        try stderr.print("ERROR: Failed to launch Chrome: {}\n", .{err});
        return;
    };

    try stdout.print("        ✓ Chrome launched successfully!\n", .{});
    try stdout.print("        - Process ID: {}\n", .{chrome_process.process_id});
    try stdout.print("        - Port: {}\n", .{chrome_process.port});
    try stdout.print("        - User Data Dir: {s}\n\n", .{chrome_process.user_data_dir orelse "default"});

    // Connect to Chrome via CDP
    try stdout.print("Step 4: Connecting to Chrome via CDP...\n", .{});
    var browser = launcher.createBrowser(chrome_process) catch |err| {
        try stderr.print("ERROR: Failed to connect to Chrome: {}\n", .{err});
        launcher.terminate(&chrome_process);
        return;
    };
    defer browser.deinit();

    try stdout.print("        ✓ Connected to CDP\n\n", .{});

    // Navigate to a URL
    const url = "https://example.com";
    try stdout.print("Step 5: Navigating to {s}...\n", .{url});
    browser.goto(url) catch |err| {
        try stderr.print("ERROR: Failed to navigate: {}\n", .{err});
        launcher.terminate(&chrome_process);
        return;
    };

    try stdout.print("        ✓ Page loaded\n\n", .{});

    // Get page title
    try stdout.print("Step 6: Getting page title...\n", .{});
    const title = browser.getTitle() catch "Unknown";
    try stdout.print("        Title: {s}\n\n", .{title});

    // Take screenshot
    try stdout.print("Step 7: Taking screenshot...\n", .{});
    const screenshot = browser.screenshot() catch |err| {
        try stderr.print("ERROR: Failed to take screenshot: {}\n", .{err});
        launcher.terminate(&chrome_process);
        return;
    };

    try stdout.print("        ✓ Screenshot captured!\n", .{});
    try stdout.print("        Size: {} bytes\n", .{screenshot.len});
    try stdout.print("        Format: Base64 PNG\n\n", .{});

    // Evaluate JavaScript
    try stdout.print("Step 8: Evaluating JavaScript...\n", .{});
    const js_result = browser.evaluate("document.documentElement.outerHTML.substring(0, 100)") catch "Error";
    try stdout.print("        Result: {s}...\n\n", .{js_result});

    // Save screenshot to file
    try stdout.print("Step 9: Saving screenshot to file...\n", .{});
    const base64 = std.base64.standard;
    const decoded = try allocator.alloc(u8, base64.calcDecodedSizeForSlice(screenshot));
    defer allocator.free(decoded);
    _ = base64.decode(decoded, screenshot);

    const screenshot_file = "screenshot.png";
    const file = try std.fs.cwd().createFile(screenshot_file, .{});
    defer file.close();
    try file.writeAll(decoded);

    try stdout.print("        ✓ Screenshot saved to {s}\n\n", .{screenshot_file});

    // Cleanup
    try stdout.print("Step 10: Cleaning up...\n", .{});
    launcher.terminate(&chrome_process);
    try stdout.print("        ✓ Chrome terminated\n\n", .{});

    try stdout.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║                      DEMO COMPLETE!                              ║\n", .{});
    try stdout.print("║   Check {s} for the screenshot                         ║\n", .{screenshot_file});
    try stdout.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});
}

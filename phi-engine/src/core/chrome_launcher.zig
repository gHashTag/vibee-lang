// VIBEE Chrome Launcher - Launch Chrome in headless mode
// Pure Zig implementation
// Chrome DevTools Protocol (CDP) automation
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const cdp = @import("cdp_client.zig");
const browser = @import("browser.zig");

pub const ChromeLauncherError = error{
    LaunchFailed,
    ChromeNotFound,
    PortInUse,
    Timeout,
    OutOfMemory,
    CommandFailed,
};

pub const ChromeConfig = struct {
    headless: bool = true,
    viewport_width: u32 = 1280,
    viewport_height: u32 = 720,
    user_agent: ?[]const u8 = null,
    remote_debugging_port: u16 = 9222,
    user_data_dir: ?[]const u8 = null,
    disable_gpu: bool = true,
    disable_sandbox: bool = false,
    timeout_ms: u32 = 30000,
    no_first_run: bool = true,
    no_default_browser_check: bool = true,
    disable_background_networking: bool = true,
    disable_background_timer_Throttling: bool = true,
    disable_breakpad: bool = true,
    disable_client_side_phishing_detection: bool = true,
    disable_default_apps: bool = true,
    disable_extensions: bool = true,
    disable_features: bool = true,
    disable_hang_monitor: bool = true,
    disable_ipc_flooding_protection: bool = true,
    disable_popup_blocking: bool = true,
    disable_prompt_on_repost: bool = true,
    disable_renderer_backgrounding: bool = true,
    disable_sync: bool = true,
    force_color_profile: bool = true,
    metrics_recording_only: bool = true,
    safebrowsing_disable_auto_update: bool = true,
    enable_automation: bool = true,
    password_store: bool = true,
    use_mock_keychain: bool = true,
};

pub const ChromeProcess = struct {
    process_id: std.process.Child.Id,
    port: u16,
    is_running: bool,
    user_data_dir: ?[]const u8,
};

pub const ChromeLauncher = struct {
    allocator: Allocator,
    config: ChromeConfig,

    const Self = @This();

    pub fn init(allocator: Allocator, config: ChromeConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.config.user_data_dir) |dir| {
            self.allocator.free(dir);
        }
    }

    /// Find Chrome executable path
    fn findChromePath(self: *Self) ChromeLauncherError![]const u8 {
        const possible_paths = [_][]const u8{
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Chromium.app/Contents/MacOS/Chromium",
            "/usr/bin/google-chrome",
            "/usr/bin/chromium",
            "/usr/bin/chromium-browser",
            "/snap/bin/chromium",
            "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
            "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
        };

        for (possible_paths) |path| {
            if (std.fs.cwd().openFile(path, .{})) |_| {
                const path_copy = self.allocator.dupe(u8, path) catch continue;
                return path_copy;
            } else |_| {
                continue;
            }
        }

        return ChromeLauncherError.ChromeNotFound;
    }

    /// Check if port is available
    fn isPortAvailable(port: u16) bool {
        const address = std.net.Address.parseIp("127.0.0.1", port) catch return false;
        const socket = std.net.tcp.getSocketToAddress(address) catch return false;
        socket.close();
        return true;
    }

    /// Create temporary user data directory
    fn createTempUserDataDir(self: *Self) ChromeLauncherError![]const u8 {
        const temp_dir = std.fs.getenv("TMPDIR") orelse "/tmp";

        var dir_name_buf: [128]u8 = undefined;
        const dir_name = std.fmt.bufPrint(&dir_name_buf, "vibee_chrome_{}", .{std.time.timestamp()}) catch return ChromeLauncherError.OutOfMemory;

        const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, dir_name });
        errdefer self.allocator.free(full_path);

        std.fs.makeDirAbsolute(full_path) catch |err| {
            if (err != error.PathAlreadyExists) return ChromeLauncherError.CommandFailed;
        };

        return full_path;
    }

    /// Launch Chrome with specified configuration
    pub fn launch(self: *Self) ChromeLauncherError!ChromeProcess {
        // Check if port is available
        if (!isPortAvailable(self.config.remote_debugging_port)) {
            return ChromeLauncherError.PortInUse;
        }

        // Find Chrome path
        const chrome_path = try self.findChromePath();
        defer self.allocator.free(chrome_path);

        // Create temp user data dir if not specified
        var user_data_dir = self.config.user_data_dir;
        if (user_data_dir == null) {
            user_data_dir = try self.createTempUserDataDir();
        }

        // Build command line arguments
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (args.items) |arg| {
                self.allocator.free(arg);
            }
            args.deinit();
        }

        try args.append(try self.allocator.dupeZ(u8, chrome_path));

        // Headless mode
        if (self.config.headless) {
            try args.append(try self.allocator.dupeZ(u8, "--headless=new"));
        }

        // Remote debugging port
        var port_buf: [32]u8 = undefined;
        const port_arg = try std.fmt.bufPrint(&port_buf, "--remote-debugging-port={d}", .{self.config.remote_debugging_port});
        try args.append(try self.allocator.dupeZ(u8, port_arg));

        // Window size
        var size_buf: [64]u8 = undefined;
        const size_arg = try std.fmt.bufPrint(&size_buf, "--window-size={d},{d}", .{ self.config.viewport_width, self.config.viewport_height });
        try args.append(try self.allocator.dupeZ(u8, size_arg));

        // User agent
        if (self.config.user_agent) |ua| {
            var ua_buf: [512]u8 = undefined;
            const ua_arg = try std.fmt.bufPrint(&ua_buf, "--user-agent={s}", .{ua});
            try args.append(try self.allocator.dupeZ(u8, ua_arg));
        }

        // User data directory
        try args.append(try self.allocator.dupeZ(u8, "--user-data-dir"));
        try args.append(try self.allocator.dupeZ(u8, user_data_dir.?));

        // Disable GPU
        if (self.config.disable_gpu) {
            try args.append(try self.allocator.dupeZ(u8, "--disable-gpu"));
        }

        // Disable sandbox
        if (self.config.disable_sandbox) {
            try args.append(try self.allocator.dupeZ(u8, "--no-sandbox"));
        }

        // Additional flags for automation
        if (self.config.no_first_run) try args.append(try self.allocator.dupeZ(u8, "--no-first-run"));
        if (self.config.no_default_browser_check) try args.append(try self.allocator.dupeZ(u8, "--no-default-browser-check"));
        if (self.config.disable_background_networking) try args.append(try self.allocator.dupeZ(u8, "--disable-background-networking"));
        if (self.config.disable_background_timer_Throttling) try args.append(try self.allocator.dupeZ(u8, "--disable-background-timer-throttling"));
        if (self.config.disable_breakpad) try args.append(try self.allocator.dupeZ(u8, "--disable-breakpad"));
        if (self.config.disable_client_side_phishing_detection) try args.append(try self.allocator.dupeZ(u8, "--disable-client-side-phishing-detection"));
        if (self.config.disable_default_apps) try args.append(try self.allocator.dupeZ(u8, "--disable-default-apps"));
        if (self.config.disable_extensions) try args.append(try self.allocator.dupeZ(u8, "--disable-extensions"));
        if (self.config.disable_features) try args.append(try self.allocator.dupeZ(u8, "--disable-features=IsolateOrigins,site-per-process"));
        if (self.config.disable_hang_monitor) try args.append(try self.allocator.dupeZ(u8, "--disable-hang-monitor"));
        if (self.config.disable_ipc_flooding_protection) try args.append(try self.allocator.dupeZ(u8, "--disable-ipc-flooding-protection"));
        if (self.config.disable_popup_blocking) try args.append(try self.allocator.dupeZ(u8, "--disable-popup-blocking"));
        if (self.config.disable_prompt_on_repost) try args.append(try self.allocator.dupeZ(u8, "--disable-prompt-on-repost"));
        if (self.config.disable_renderer_backgrounding) try args.append(try self.allocator.dupeZ(u8, "--disable-renderer-backgrounding"));
        if (self.config.disable_sync) try args.append(try self.allocator.dupeZ(u8, "--disable-sync"));
        if (self.config.force_color_profile) try args.append(try self.allocator.dupeZ(u8, "--force-color-profile=srgb"));
        if (self.config.metrics_recording_only) try args.append(try self.allocator.dupeZ(u8, "--metrics-recording-only"));
        if (self.config.safebrowsing_disable_auto_update) try args.append(try self.allocator.dupeZ(u8, "--safebrowsing-disable-auto-update"));
        if (self.config.enable_automation) try args.append(try self.allocator.dupeZ(u8, "--enable-automation"));
        if (self.config.password_store) try args.append(try self.allocator.dupeZ(u8, "--password-store=basic"));
        if (self.config.use_mock_keychain) try args.append(try self.allocator.dupeZ(u8, "--use-mock-keychain"));

        // Run Chrome
        var process = std.process.Child.init(args.items, self.allocator);
        process.stdin_behavior = .Ignore;
        process.stdout_behavior = .Pipe;
        process.stderr_behavior = .Pipe;

        try process.spawn();

        const pid = process.id;

        // Don't kill process - let it run in background
        _ = &process.stdout;
        _ = &process.stderr;

        // Wait for Chrome to start and CDP to be available
        var tries: u32 = 0;
        const max_tries = self.config.timeout_ms / 100;

        while (tries < max_tries) : (tries += 1) {
            std.time.sleep(100 * std.time.ns_per_ms);

            if (isPortAvailable(self.config.remote_debugging_port)) {
                // Port is still available, Chrome hasn't started yet
                continue;
            }

            // Port is in use, Chrome should be ready
            break;
        }

        if (tries >= max_tries) {
            return ChromeLauncherError.Timeout;
        }

        return ChromeProcess{
            .process_id = pid,
            .port = self.config.remote_debugging_port,
            .is_running = true,
            .user_data_dir = user_data_dir,
        };
    }

    /// Create browser client connected to launched Chrome
    pub fn createBrowser(self: *Self, chrome_process: ChromeProcess) !browser.Browser {
        const browser_config = browser.BrowserConfig{
            .host = "localhost",
            .port = chrome_process.port,
            .headless = self.config.headless,
            .viewport_width = self.config.viewport_width,
            .viewport_height = self.config.viewport_height,
        };

        var b = browser.Browser.init(self.allocator, browser_config);
        try b.connect();

        return b;
    }

    /// Terminate Chrome process
    pub fn terminate(self: *Self, chrome_process: *ChromeProcess) void {
        if (!chrome_process.is_running) return;

        // Kill the process
        std.process.kill(chrome_process.process_id) catch {};

        chrome_process.is_running = false;

        // Clean up user data directory
        if (chrome_process.user_data_dir) |dir| {
            std.fs.deleteTreeAbsolute(dir) catch {};
            self.allocator.free(dir);
            chrome_process.user_data_dir = null;
        }
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "find chrome path" {
    const allocator = std.testing.allocator;
    var launcher = ChromeLauncher.init(allocator, ChromeConfig{});

    const path = launcher.findChromePath() catch |err| {
        if (err == ChromeLauncherError.ChromeNotFound) {
            return; // Chrome not installed, skip test
        }
        return err;
    };
    defer allocator.free(path);

    try std.testing.expect(path.len > 0);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "chrome config defaults" {
    const config = ChromeConfig{};
    try std.testing.expectEqual(true, config.headless);
    try std.testing.expectEqual(@as(u16, 9222), config.remote_debugging_port);
    try std.testing.expectEqual(@as(u32, 1280), config.viewport_width);
    try std.testing.expectEqual(@as(u32, 720), config.viewport_height);
}

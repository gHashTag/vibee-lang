// VIBEE CHROME LAUNCHER - WITH VALIDATION INTEGRATION
// Launch Chrome in headless mode + runs 33 Bogatyrs validation
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const Allocator = std.mem.Allocator;
const registry_mod = @import("bogatyr_registry.zig");

pub const ChromeLauncherConfig = struct {
    headless: bool = true,
    viewport_width: u32 = 1280,
    viewport_height: u32 = 720,
    user_agent: ?[]const u8 = null,
    remote_debugging_port: u16 = 9222,
    user_data_dir: ?[]const u8 = null,
    disable_gpu: bool = true,
    disable_sandbox: bool = false,
    timeout_ms: u32 = 30000,

    // Validation
    validate_spec_before_launch: bool = true,
    strict_validation: bool = false,
    spec_path: ?[]const u8 = null,
};

pub const ChromeProcess = struct {
    process_id: std.process.Child.Id,
    port: u16,
    websocket_url: []const u8,
    is_running: bool,
    user_data_dir: ?[]const u8,
};

pub const ChromeLauncherError = error{
    ChromeNotFound,
    PortInUse,
    ValidationFailed,
    LaunchFailed,
    Timeout,
    OutOfMemory,
};

pub const ChromeLauncher = struct {
    allocator: Allocator,
    config: ChromeLauncherConfig,
    registry: *registry_mod.BogatyrRegistry,

    const Self = @This();

    pub fn init(allocator: Allocator, config: ChromeLauncherConfig, registry: *registry_mod.BogatyrRegistry) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .registry = registry,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
        // Registry деинициализируется снаружи
    }

    /// Запуск Chrome с предварительной валидацией
    pub fn launchWithValidation(self: *Self) !ChromeProcess {
        // Валидация перед запуском (если включено)
        if (self.config.validate_spec_before_launch and self.config.spec_path != null) {
            const source = self.allocator.alloc(u8, 2048) catch return ChromeLauncherError.OutOfMemory;
            defer self.allocator.free(source);

            // Читаем .vibee файл
            const spec_source = std.fs.cwd().readFileAlloc(self.allocator, self.config.spec_path.?, 4096) catch |err| {
                _ = err;
                return ChromeLauncherError.ValidationFailed;
            };
            defer self.allocator.free(spec_source);

            // Создаем валидационный контекст
            const validation_config = registry_mod.ValidationConfig{
                .strict_mode = self.config.strict_validation,
                .warning_as_error = false,
                .cache_enabled = true,
                .parallel_enabled = false, // Сначала последовательно
                .timeout_ms = @min(self.config.timeout_ms / 2, 1000), // Меньше timeout для валидации
            };

            const validation_context = registry_mod.ValidationContext{
                .allocator = self.allocator,
                .spec_path = self.config.spec_path.?,
                .source = spec_source,
                .config = validation_config,
                .ast = null,
                .symbol_table = null,
            };

            // Запускаем все богатыри
            const plugin_count = self.registry.pluginCount();
            var errors_found: usize = 0;

            const plugins = try self.registry.getAllPlugins();
            defer {
                for (plugins) |plugin| {
                    self.allocator.free(plugin);
                }
                self.allocator.free(plugins);
            }

            for (plugins) |plugin| {
                const result = plugin.validate(&validation_context) catch |err| {
                    std.debug.print("Bogatyr '{s}' failed: {}\n", .{ plugin.name, err });
                    errors_found += 1;
                    continue;
                };

                for (result.errors) |err| {
                    std.debug.print("  [{s}:{d}] {s}: {s}\n", .{
                        self.config.spec_path.?,
                        err.line,
                        err.code,
                        err.message,
                    });
                }
            }

            if (errors_found > 0) {
                std.debug.print("Validation FAILED: {} errors found\n", .{errors_found});
                return ChromeLauncherError.ValidationFailed;
            }

            // Если валидация прошла - продолжаем
            std.debug.print("✅ All {} bogatyrs passed validation\n", .{plugin_count});
        }

        // Запуск Chrome
        return self.launch();
    }

    /// Запуск Chrome без валидации
    pub fn launch(self: *Self) !ChromeProcess {
        const chrome_path = try self.findChromePath() catch |err| {
            std.debug.print("❌ Chrome not found: {}\n", .{err});
            return ChromeLauncherError.ChromeNotFound;
        };
        defer self.allocator.free(chrome_path);

        const temp_user_data_dir = try self.createTempUserDataDir() catch |err| {
            _ = err;
            return ChromeLauncherError.OutOfMemory;
        };
        defer {
            if (temp_user_data_dir) |dir| {
                if (self.config.user_data_dir == null) {
                    std.fs.deleteTreeAbsolute(dir) catch {};
                    self.allocator.free(dir);
                }
            }
        }

        const port = self.config.remote_debugging_port;
        if (!self.isPortAvailable(port)) {
            std.debug.print("❌ Port {} is already in use\n", .{port});
            return ChromeLauncherError.PortInUse;
        }

        // Формируем аргументы для запуска
        const allocator = self.allocator;
        var args = std.ArrayList([]const u8).init(allocator);
        defer {
            for (args.items) |arg| {
                allocator.free(arg);
            }
            args.deinit();
        }

        try args.append("chromium-browser") catch return ChromeLauncherError.OutOfMemory;

        try args.append("--headless=new") catch return ChromeLauncherError.OutOfMemory;

        try args.append("--disable-gpu") catch return ChromeLauncherError.OutOfMemory;

        try args.append("--disable-software-rasterizer") catch return ChromeLauncherError.OutOfMemory;

        // Viewport size
        const size_buf = try std.fmt.allocPrint(allocator, "window-size={},{}", .{ self.config.viewport_width, self.config.viewport_height }) catch return ChromeLauncherError.OutOfMemory;
        defer allocator.free(size_buf);
        try args.append(size_buf) catch return ChromeLauncherError.OutOfMemory;

        // Remote debugging port
        const port_buf = try std.fmt.allocPrint(allocator, "--remote-debugging-port={d}", .{port}) catch return ChromeLauncherError.OutOfMemory;
        defer allocator.free(port_buf);
        try args.append(port_buf) catch return ChromeLauncherError.OutOfMemory;

        // User agent
        if (self.config.user_agent) |ua| {
            const agent_buf = try std.fmt.allocPrint(allocator, "--user-agent={s}", .{ua}) catch return ChromeLauncherError.OutOfMemory;
            defer allocator.free(agent_buf);
            try args.append(agent_buf) catch return ChromeLauncherError.OutOfMemory;
        }

        // User data directory
        if (self.config.user_data_dir) |dir| {
            const dir_buf = try std.fmt.allocPrint(allocator, "--user-data-dir={s}", .{dir}) catch return ChromeLauncherError.OutOfMemory;
            defer allocator.free(dir_buf);
            try args.append(dir_buf) catch return ChromeLauncherError.OutOfMemory;
        }

        // Disable sandbox
        if (self.config.disable_sandbox) {
            try args.append("--no-sandbox") catch return ChromeLauncherError.OutOfMemory;
        }

        // Disable various features
        const disable_args = [_][]const u8{
            "--disable-background-networking",
            "--disable-background-timer-throttling",
            "--disable-breakpad",
            "--disable-client-side-phishing-detection",
            "--disable-default-apps",
            "--disable-extensions",
            "--disable-hang-monitor",
            "--disable-popup-blocking",
            "--disable-prompt-on-repost",
            "--disable-renderer-backgrounding",
            "--disable-sync",
            "--disable-translate",
            "--disable-features=IsolateOrigins,site-per-process",
            "--force-color-profile=srgb",
            "--metrics-recording-only",
            "--safebrowsing-mode",
            "--enable-automation",
            "--password-store=basic",
            "--use-mock-keychain",
        };

        for (disable_args) |disable_arg| {
            try args.append(disable_arg) catch |err| {
                _ = err;
                std.debug.print("Warning: Failed to add flag: {s}\n", .{disable_arg});
            };
        }

        // URL to navigate to (или пустой для чистой запуска)
        const url = std.os.getenv("VIBEE_LAUNCH_URL") orelse "about:blank";

        const url_buf = try std.fmt.allocPrint(allocator, "{s}", .{url}) catch return ChromeLauncherError.OutOfMemory;
        defer allocator.free(url_buf);
        try args.append(url_buf) catch return ChromeLauncherError.OutOfMemory;

        // Запуска Chrome
        var process = std.process.Child.init(args.items, self.allocator) catch |err| {
            std.debug.print("❌ Failed to launch Chrome: {}\n", .{err});
            return ChromeLauncherError.LaunchFailed;
        };

        // SPAWN процесс (запуск без блокировки)
        try process.spawn() catch |err| {
            std.debug.print("❌ Failed to spawn Chrome: {}\n", .{err});
            return ChromeLauncherError.LaunchFailed;
        };

        const pid = process.id;

        // Проверяем что Chrome запустился (ждем когда порт станет занят)
        var tries: u32 = 0;
        const max_tries = self.config.timeout_ms / 100; // 100мс интервал

        while (tries < max_tries) : (tries += 1) {
            std.time.sleep(100 * std.time.ns_per_ms);

            if (!self.isPortAvailable(port)) break;
        }

        const user_data_dir_copy = self.config.user_data_dir;

        const ws_url_buf = try std.fmt.allocPrint(allocator, "ws://127.0.0.1:{d}", .{port}) catch return ChromeLauncherError.OutOfMemory;

        return ChromeProcess{
            .process_id = pid,
            .port = port,
            .websocket_url = ws_url_buf,
            .is_running = true,
            .user_data_dir = user_data_dir_copy,
        };
    }

    /// Проверка доступности порта
    fn isPortAvailable(port: u16) bool {
        const address = std.net.Address.parseIp("127.0.0.1", port) catch return false;
        const socket = std.net.tcp.getSocketToAddress(address) catch return true;
        socket.close();
        return true;
    }

    /// Поиск Chrome executable
    fn findChromePath(self: *const Self) ![]const u8 {
        const possible_paths = [_][]const u8{
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Chromium.app/Contents/MacOS/Chromium",
            "/usr/bin/google-chrome",
            "/usr/bin/chromium",
            "/usr/bin/chromium-browser",
            "/snap/bin/chromium",
        };

        for (possible_paths) |path| {
            if (std.fs.cwd().openFile(path, .{})) |file| {
                defer file.close();
                return self.allocator.dupeZ(u8, path) catch continue;
            }
        }

        return ChromeLauncherError.ChromeNotFound;
    }

    /// Создание временной директории для пользовательских данных
    fn createTempUserDataDir(self: *Self) ![]const u8 {
        const temp_dir = std.fs.getenv("TMPDIR") orelse "/tmp";

        const dir_name_buf = try self.allocator.allocPrint(u8, "vibee_chrome_{}", .{std.time.timestamp()}) catch return ChromeLauncherError.OutOfMemory;
        defer self.allocator.free(dir_name_buf);

        const dir_path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, dir_name_buf }) catch |err| {
            _ = err;
            return ChromeLauncherError.OutOfMemory;
        };

        try std.fs.makeDirAbsolute(dir_path) catch |err| {
            _ = err;
            return ChromeLauncherError.OutOfMemory;
        };

        return dir_path;
    }

    /// Завершение процесса Chrome
    pub fn terminate(self: *Self, chrome_process: *ChromeProcess) void {
        if (!chrome_process.is_running) return;

        // Убиваем процесс
        if (std.process.kill(chrome_process.process_id)) |_| {
            chrome_process.is_running = false;
            std.debug.print("✓ Chrome terminated: pid={}\n", .{chrome_process.process_id});
        }

        // Очищаем директорию пользователя
        if (chrome_process.user_data_dir) |dir| {
            std.fs.deleteTreeAbsolute(dir) catch |err| {
                _ = err;
                std.debug.print("Warning: Failed to delete temp dir: {}\n", .{dir});
            };
            self.allocator.free(dir);
        }
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "chrome launcher config defaults" {
    const config = ChromeLauncherConfig{};
    try std.testing.expectEqual(true, config.headless);
    try std.testing.expectEqual(@as(u16, 9222), config.remote_debugging_port);
    try std.testing.expectEqual(@as(u32, 1280), config.viewport_width);
    try std.testing.expectEqual(@as(u32, 720), config.viewport_height);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "chrome launcher with validation disabled" {
    const allocator = std.testing.allocator;

    var registry = try registry_mod.BogatyrRegistry.init(allocator) catch |err| {
        std.debug.print("Failed to init registry: {}\n", .{err});
        std.testing.expectError(ChromeLauncherError.OutOfMemory);
        return;
    };
    defer registry.deinit();

    const config = ChromeLauncherConfig{
        .validate_spec_before_launch = false,
        .timeout_ms = 5000,
    };

    var launcher = try ChromeLauncher.init(allocator, config, &registry);
    defer launcher.deinit();

    // Тест без валидации Chrome не запускаем
}

test "port availability" {
    const allocator = std.testing.allocator;

    var registry = try registry_mod.BogatyrRegistry.init(allocator) catch |err| {
        std.debug.print("Failed to init registry: {}\n", .{err});
        std.testing.expectError(ChromeLauncherError.OutOfMemory);
        return;
    };
    defer registry.deinit();

    // Проверяем что порт 9222 свободен (Chrome не запущен)
    const config = ChromeLauncherConfig{};
    var launcher = try ChromeLauncher.init(allocator, config, &registry) catch |err| {
        _ = err;
        std.testing.expectError(ChromeLauncherError.OutOfMemory);
        return;
    };
    defer launcher.deinit();

    const port = launcher.isPortAvailable(9222);
    try std.testing.expect(port == true);
}

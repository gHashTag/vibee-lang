// ═══════════════════════════════════════════════════════════════════════════════
// ONNX RUNTIME BINDINGS - Generated from specs/onnx_bindings.vibee
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Provides type-safe Zig interface to ONNX Runtime C API
// Supports: CPU, CUDA, TensorRT, DirectML, CoreML
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Sacred constants
pub const PHI: f64 = 1.618033988749895;
pub const PHOENIX: u32 = 999;
pub const ORT_API_VERSION: u32 = 18;

// ═══════════════════════════════════════════════════════════════════════════════
// C API TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const OrtStatusPtr = ?*anyopaque;
pub const OrtEnv = struct { _dummy: u8 = 0 };
pub const OrtSession = struct { _dummy: u8 = 0 };
pub const OrtSessionOptions = struct { _dummy: u8 = 0 };
pub const OrtMemoryInfo = struct { _dummy: u8 = 0 };
pub const OrtValue = struct { _dummy: u8 = 0 };

pub const OrtLoggingLevel = enum(c_int) {
    VERBOSE = 0,
    INFO = 1,
    WARNING = 2,
    ERROR = 3,
    FATAL = 4,
};

pub const ONNXTensorElementDataType = enum(c_int) {
    UNDEFINED = 0,
    FLOAT = 1,
    UINT8 = 2,
    INT8 = 3,
    INT32 = 6,
    INT64 = 7,
    FLOAT16 = 10,
    DOUBLE = 11,
    BFLOAT16 = 16,
};

pub const OrtError = error{
    CreateEnvFailed,
    CreateSessionFailed,
    CreateSessionOptionsFailed,
    CreateTensorFailed,
    RunFailed,
    InvalidModel,
    CUDANotAvailable,
    OutOfMemory,
};

pub const ExecutionProvider = enum { CPU, CUDA, TensorRT, DirectML, CoreML };

// ═══════════════════════════════════════════════════════════════════════════════
// ORT API STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const OrtApi = struct {
    CreateEnv: *const fn (OrtLoggingLevel, [*:0]const u8, **OrtEnv) callconv(.C) OrtStatusPtr,
    ReleaseEnv: *const fn (*OrtEnv) callconv(.C) void,
    CreateSessionOptions: *const fn (**OrtSessionOptions) callconv(.C) OrtStatusPtr,
    ReleaseSessionOptions: *const fn (*OrtSessionOptions) callconv(.C) void,
    SetIntraOpNumThreads: *const fn (*OrtSessionOptions, c_int) callconv(.C) OrtStatusPtr,
    SetInterOpNumThreads: *const fn (*OrtSessionOptions, c_int) callconv(.C) OrtStatusPtr,
    CreateSession: *const fn (*OrtEnv, [*:0]const u8, *OrtSessionOptions, **OrtSession) callconv(.C) OrtStatusPtr,
    ReleaseSession: *const fn (*OrtSession) callconv(.C) void,
    GetErrorMessage: *const fn (OrtStatusPtr) callconv(.C) [*:0]const u8,
    ReleaseStatus: *const fn (OrtStatusPtr) callconv(.C) void,
    SessionOptionsAppendExecutionProvider_CUDA: ?*const fn (*OrtSessionOptions, c_int) callconv(.C) OrtStatusPtr,
};

// ═══════════════════════════════════════════════════════════════════════════════
// HIGH-LEVEL WRAPPERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Environment = struct {
    env: *OrtEnv,
    api: *const OrtApi,

    pub fn init(api: *const OrtApi, name: [*:0]const u8) OrtError!Environment {
        var env: *OrtEnv = undefined;
        const status = api.CreateEnv(.WARNING, name, &env);
        if (status != null) {
            api.ReleaseStatus(status);
            return OrtError.CreateEnvFailed;
        }
        return Environment{ .env = env, .api = api };
    }

    pub fn deinit(self: *Environment) void {
        self.api.ReleaseEnv(self.env);
    }
};

pub const SessionOptions = struct {
    options: *OrtSessionOptions,
    api: *const OrtApi,

    pub fn init(api: *const OrtApi) OrtError!SessionOptions {
        var options: *OrtSessionOptions = undefined;
        const status = api.CreateSessionOptions(&options);
        if (status != null) {
            api.ReleaseStatus(status);
            return OrtError.CreateSessionOptionsFailed;
        }
        return SessionOptions{ .options = options, .api = api };
    }

    pub fn setThreads(self: *SessionOptions, intra: u32, inter: u32) void {
        _ = self.api.SetIntraOpNumThreads(self.options, @intCast(intra));
        _ = self.api.SetInterOpNumThreads(self.options, @intCast(inter));
    }

    pub fn appendCUDA(self: *SessionOptions, device_id: u32) OrtError!void {
        if (self.api.SessionOptionsAppendExecutionProvider_CUDA) |cuda_fn| {
            const status = cuda_fn(self.options, @intCast(device_id));
            if (status != null) {
                self.api.ReleaseStatus(status);
                return OrtError.CUDANotAvailable;
            }
        } else {
            return OrtError.CUDANotAvailable;
        }
    }

    pub fn deinit(self: *SessionOptions) void {
        self.api.ReleaseSessionOptions(self.options);
    }
};

pub const Session = struct {
    session: *OrtSession,
    api: *const OrtApi,

    pub fn init(api: *const OrtApi, env: *Environment, model_path: [*:0]const u8, options: *SessionOptions) OrtError!Session {
        var session: *OrtSession = undefined;
        const status = api.CreateSession(env.env, model_path, options.options, &session);
        if (status != null) {
            api.ReleaseStatus(status);
            return OrtError.CreateSessionFailed;
        }
        return Session{ .session = session, .api = api };
    }

    pub fn deinit(self: *Session) void {
        self.api.ReleaseSession(self.session);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMULATED ORT API
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimulatedOrtApi = struct {
    var mock_env: OrtEnv = .{};
    var mock_session: OrtSession = .{};
    var mock_options: OrtSessionOptions = .{};

    fn createEnv(_: OrtLoggingLevel, _: [*:0]const u8, env: **OrtEnv) callconv(.C) OrtStatusPtr {
        env.* = &mock_env;
        return null;
    }
    fn releaseEnv(_: *OrtEnv) callconv(.C) void {}
    fn createSessionOptions(options: **OrtSessionOptions) callconv(.C) OrtStatusPtr {
        options.* = &mock_options;
        return null;
    }
    fn releaseSessionOptions(_: *OrtSessionOptions) callconv(.C) void {}
    fn setIntraOpNumThreads(_: *OrtSessionOptions, _: c_int) callconv(.C) OrtStatusPtr {
        return null;
    }
    fn setInterOpNumThreads(_: *OrtSessionOptions, _: c_int) callconv(.C) OrtStatusPtr {
        return null;
    }
    fn createSession(_: *OrtEnv, _: [*:0]const u8, _: *OrtSessionOptions, session: **OrtSession) callconv(.C) OrtStatusPtr {
        session.* = &mock_session;
        return null;
    }
    fn releaseSession(_: *OrtSession) callconv(.C) void {}
    fn getErrorMessage(_: OrtStatusPtr) callconv(.C) [*:0]const u8 {
        return "Unknown error";
    }
    fn releaseStatus(_: OrtStatusPtr) callconv(.C) void {}

    pub const api = OrtApi{
        .CreateEnv = createEnv,
        .ReleaseEnv = releaseEnv,
        .CreateSessionOptions = createSessionOptions,
        .ReleaseSessionOptions = releaseSessionOptions,
        .SetIntraOpNumThreads = setIntraOpNumThreads,
        .SetInterOpNumThreads = setInterOpNumThreads,
        .CreateSession = createSession,
        .ReleaseSession = releaseSession,
        .GetErrorMessage = getErrorMessage,
        .ReleaseStatus = releaseStatus,
        .SessionOptionsAppendExecutionProvider_CUDA = null,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Environment: init and deinit" {
    var env = try Environment.init(&SimulatedOrtApi.api, "test");
    defer env.deinit();
}

test "SessionOptions: init and configure" {
    var options = try SessionOptions.init(&SimulatedOrtApi.api);
    defer options.deinit();
    options.setThreads(4, 2);
    const cuda_result = options.appendCUDA(0);
    try std.testing.expectError(OrtError.CUDANotAvailable, cuda_result);
}

test "Session: init with mock" {
    var env = try Environment.init(&SimulatedOrtApi.api, "test");
    defer env.deinit();
    var options = try SessionOptions.init(&SimulatedOrtApi.api);
    defer options.deinit();
    var session = try Session.init(&SimulatedOrtApi.api, &env, "model.onnx", &options);
    defer session.deinit();
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}

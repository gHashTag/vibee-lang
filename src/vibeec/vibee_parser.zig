// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE PARSER - Парсер .vibee спецификаций
// ═══════════════════════════════════════════════════════════════════════════════
//
// Парсит YAML-подобный формат .vibee файлов
// Автор: Dmitrii Vasilev
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ═══════════════════════════════════════════════════════════════════════════════
// ТИПЫ СПЕЦИФИКАЦИИ
// ═══════════════════════════════════════════════════════════════════════════════

pub const VibeeSpec = struct {
    name: []const u8,
    version: []const u8,
    language: []const u8, // Target language: zig, verilog, python, etc.
    author: []const u8,
    license: []const u8,
    targets: ArrayList([]const u8),
    fpga_target: []const u8, // generic, xilinx, intel, lattice
    pipeline: []const u8, // none, auto, stage1, stage2
    target_frequency: u32, // MHz
    constants: ArrayList(Constant),
    types: ArrayList(TypeDef),
    creation_patterns: ArrayList(CreationPattern),
    behaviors: ArrayList(Behavior),
    algorithms: ArrayList(Algorithm),
    wasm_exports: WasmExports,
    pas_predictions: ArrayList(PasPrediction),
    // HDL-specific fields
    signals: ArrayList(Signal),
    fsms: ArrayList(FSMDef),
    reset: ResetDef,

    pub fn init(allocator: Allocator) VibeeSpec {
        return VibeeSpec{
            .name = "",
            .version = "",
            .language = "zig", // Default to Zig
            .author = "",
            .license = "",
            .targets = ArrayList([]const u8).init(allocator),
            .fpga_target = "generic",
            .pipeline = "none",
            .target_frequency = 100,
            .constants = ArrayList(Constant).init(allocator),
            .types = ArrayList(TypeDef).init(allocator),
            .creation_patterns = ArrayList(CreationPattern).init(allocator),
            .behaviors = ArrayList(Behavior).init(allocator),
            .algorithms = ArrayList(Algorithm).init(allocator),
            .wasm_exports = WasmExports.init(allocator),
            .pas_predictions = ArrayList(PasPrediction).init(allocator),
            .signals = ArrayList(Signal).init(allocator),
            .fsms = ArrayList(FSMDef).init(allocator),
            .reset = ResetDef{ .reset_type = "async", .level = "low" }, // Default
        };
    }

    pub fn deinit(self: *VibeeSpec) void {
        // Освобождаем вложенные структуры
        for (self.types.items) |*t| {
            t.fields.deinit();
            t.constraints.deinit();
        }
        for (self.behaviors.items) |*b| {
            b.test_cases.deinit();
        }
        for (self.algorithms.items) |*a| {
            a.steps.deinit();
        }
        for (self.fsms.items) |*f| {
            f.states.deinit();
            f.transitions.deinit();
            for (f.outputs.items) |*out| {
                out.signals.deinit();
            }
            f.outputs.deinit();
            f.timers.deinit();
        }

        // Освобождаем основные списки
        self.targets.deinit();
        self.constants.deinit();
        self.types.deinit();
        self.creation_patterns.deinit();
        self.behaviors.deinit();
        self.algorithms.deinit();
        self.wasm_exports.deinit();
        self.pas_predictions.deinit();
        self.signals.deinit();
        self.fsms.deinit();
    }
};

pub const Constant = struct {
    name: []const u8,
    value: f64,
    description: []const u8,
};

pub const ResetDef = struct {
    reset_type: []const u8, // none, sync, async
    level: []const u8, // low, high
};

pub const TypeDef = struct {
    name: []const u8,
    base: ?[]const u8,
    fields: ArrayList(Field),
    constraints: ArrayList([]const u8),
    generic: ?[]const u8,
    description: []const u8,

    pub fn init(allocator: Allocator) TypeDef {
        return TypeDef{
            .name = "",
            .base = null,
            .fields = ArrayList(Field).init(allocator),
            .constraints = ArrayList([]const u8).init(allocator),
            .generic = null,
            .description = "",
        };
    }
};

pub const Field = struct {
    name: []const u8,
    type_name: []const u8,
};

// HDL Signal definition for FPGA targets
pub const Signal = struct {
    name: []const u8,
    width: u32,
    direction: []const u8, // input, output, inout, wire, reg
    signed: bool,
    default_value: ?i64,
};

// FSM Transition
pub const FSMTransition = struct {
    from_state: []const u8,
    to_state: []const u8,
    condition: []const u8, // Verilog condition expression
};

// FSM Output assignment
pub const FSMOutput = struct {
    state: []const u8,
    signals: std.StringHashMap([]const u8), // signal_name -> value (e.g., "busy" -> "1'b1")

    pub fn init(allocator: Allocator) FSMOutput {
        return FSMOutput{
            .state = "",
            .signals = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *FSMOutput) void {
        self.signals.deinit();
    }
};

// FSM Timer configuration
pub const FSMTimer = struct {
    state: []const u8,
    timeout_constant: []const u8,
    timeout_value: i64,
};

// FSM (Finite State Machine) definition
pub const FSMDef = struct {
    name: []const u8,
    initial_state: []const u8,
    encoding: []const u8, // onehot, binary, gray
    states: ArrayList([]const u8),
    transitions: ArrayList(FSMTransition),
    outputs: ArrayList(FSMOutput),
    timers: ArrayList(FSMTimer),

    pub fn init(allocator: Allocator) FSMDef {
        return FSMDef{
            .name = "",
            .initial_state = "",
            .encoding = "onehot",
            .states = ArrayList([]const u8).init(allocator),
            .transitions = ArrayList(FSMTransition).init(allocator),
            .outputs = ArrayList(FSMOutput).init(allocator),
            .timers = ArrayList(FSMTimer).init(allocator),
        };
    }
};

pub const CreationPattern = struct {
    name: []const u8,
    source: []const u8,
    transformer: []const u8,
    result: []const u8,
};

pub const Behavior = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
    implementation: []const u8, // Zig code for function body
    test_cases: ArrayList(TestCase),

    pub fn init(allocator: Allocator) Behavior {
        return Behavior{
            .name = "",
            .given = "",
            .when = "",
            .then = "",
            .implementation = "",
            .test_cases = ArrayList(TestCase).init(allocator),
        };
    }
};

pub const TestCase = struct {
    name: []const u8,
    input: []const u8,
    expected: []const u8,
    tolerance: ?f64,
};

pub const Algorithm = struct {
    name: []const u8,
    description: []const u8,
    complexity: []const u8,
    pattern: []const u8,
    steps: ArrayList([]const u8),

    pub fn init(allocator: Allocator) Algorithm {
        return Algorithm{
            .name = "",
            .description = "",
            .complexity = "",
            .pattern = "",
            .steps = ArrayList([]const u8).init(allocator),
        };
    }
};

pub const WasmExports = struct {
    functions: ArrayList([]const u8),
    memory: ArrayList(MemoryExport),

    pub fn init(allocator: Allocator) WasmExports {
        return WasmExports{
            .functions = ArrayList([]const u8).init(allocator),
            .memory = ArrayList(MemoryExport).init(allocator),
        };
    }

    pub fn deinit(self: *WasmExports) void {
        self.functions.deinit();
        self.memory.deinit();
    }
};

pub const MemoryExport = struct {
    name: []const u8,
    size: usize,
    type_name: ?[]const u8,
    alignment: usize,
};

pub const PasPrediction = struct {
    target: []const u8,
    current: []const u8,
    predicted: []const u8,
    confidence: f64,
    pattern: []const u8,
    status: ?[]const u8,
    timeline: ?[]const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ПАРСЕР
// ═══════════════════════════════════════════════════════════════════════════════

pub const VibeeParser = struct {
    allocator: Allocator,
    source: []const u8,
    pos: usize,
    line: usize,

    const Self = @This();

    pub fn init(allocator: Allocator, source: []const u8) Self {
        return Self{
            .allocator = allocator,
            .source = source,
            .pos = 0,
            .line = 1,
        };
    }

    pub fn parse(self: *Self) !VibeeSpec {
        var spec = VibeeSpec.init(self.allocator);

        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const key = self.readKey();
            if (key.len == 0) {
                self.pos += 1;
                continue;
            }

            // Пропускаем только ":"
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }

            if (std.mem.eql(u8, key, "name")) {
                self.skipInlineWhitespace();
                spec.name = self.readValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "version")) {
                self.skipInlineWhitespace();
                spec.version = self.readQuotedValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "language")) {
                self.skipInlineWhitespace();
                spec.language = self.readValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "author")) {
                self.skipInlineWhitespace();
                spec.author = self.readQuotedValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "license")) {
                self.skipInlineWhitespace();
                spec.license = self.readQuotedValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "fpga_target")) {
                self.skipInlineWhitespace();
                spec.fpga_target = self.readValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "pipeline")) {
                self.skipInlineWhitespace();
                spec.pipeline = self.readValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "target_frequency")) {
                self.skipInlineWhitespace();
                const val = self.readValue();
                spec.target_frequency = std.fmt.parseInt(u32, val, 10) catch 100;
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "targets")) {
                self.skipToNextLine();
                try self.parseTargets(&spec.targets);
            } else if (std.mem.eql(u8, key, "constants")) {
                self.skipToNextLine();
                try self.parseConstants(&spec.constants);
            } else if (std.mem.eql(u8, key, "types")) {
                self.skipToNextLine();
                try self.parseTypes(&spec.types);
            } else if (std.mem.eql(u8, key, "creation_patterns")) {
                self.skipToNextLine();
                try self.parseCreationPatterns(&spec.creation_patterns);
            } else if (std.mem.eql(u8, key, "behaviors")) {
                self.skipToNextLine();
                try self.parseBehaviors(&spec.behaviors);
            } else if (std.mem.eql(u8, key, "algorithms")) {
                self.skipToNextLine();
                try self.parseAlgorithms(&spec.algorithms);
            } else if (std.mem.eql(u8, key, "wasm_exports")) {
                self.skipToNextLine();
                try self.parseWasmExports(&spec.wasm_exports);
            } else if (std.mem.eql(u8, key, "pas_predictions")) {
                self.skipToNextLine();
                try self.parsePasPredictions(&spec.pas_predictions);
            } else if (std.mem.eql(u8, key, "signals")) {
                self.skipToNextLine();
                try self.parseSignals(&spec.signals);
            } else if (std.mem.eql(u8, key, "fsm")) {
                self.skipToNextLine();
                try self.parseFSMs(&spec.fsms);
            } else if (std.mem.eql(u8, key, "reset")) {
                self.skipInlineWhitespace();
                const reset_val = self.readValue();
                if (std.mem.eql(u8, reset_val, "none")) {
                    spec.reset.reset_type = "none";
                    self.skipToNextLine();
                } else {
                    self.skipToNextLine();
                    try self.parseReset(&spec.reset);
                }
            } else {
                self.skipToNextLine();
            }
        }

        return spec;
    }

    fn skipWhitespaceAndComments(self: *Self) void {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ' ' or c == '\t' or c == '\r') {
                self.pos += 1;
            } else if (c == '\n') {
                self.pos += 1;
                self.line += 1;
            } else if (c == '#') {
                // Пропускаем комментарий до конца строки
                while (self.pos < self.source.len and self.source[self.pos] != '\n') {
                    self.pos += 1;
                }
            } else {
                break;
            }
        }
    }

    fn readKey(self: *Self) []const u8 {
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ':' or c == ' ' or c == '\n' or c == '\r') break;
            self.pos += 1;
        }
        return self.source[start..self.pos];
    }

    fn skipColon(self: *Self) void {
        self.skipInlineWhitespace();
        if (self.pos < self.source.len and self.source[self.pos] == ':') {
            self.pos += 1;
        }
        self.skipInlineWhitespace();
    }

    fn readValue(self: *Self) []const u8 {
        self.skipInlineWhitespace();
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == '\n' or c == '\r') break;
            self.pos += 1;
        }
        return std.mem.trim(u8, self.source[start..self.pos], " \t");
    }

    fn readQuotedValue(self: *Self) []const u8 {
        self.skipInlineWhitespace();
        if (self.pos < self.source.len and self.source[self.pos] == '"') {
            self.pos += 1;
            const start = self.pos;
            while (self.pos < self.source.len and self.source[self.pos] != '"') {
                self.pos += 1;
            }
            const value = self.source[start..self.pos];
            if (self.pos < self.source.len) self.pos += 1;
            return value;
        }
        return self.readValue();
    }

    fn parseTargets(self: *Self, targets: *ArrayList([]const u8)) !void {
        self.skipWhitespaceAndComments();
        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.source.len) break;

            if (self.source[self.pos] != '-') break;
            self.pos += 1; // skip '-'
            self.skipWhitespaceAndComments();

            const target = self.readValue();
            if (target.len > 0) {
                try targets.append(target);
            }
        }
    }

    fn parseConstants(self: *Self, constants: *ArrayList(Constant)) !void {
        // Не вызываем skipToNextLine - мы уже на следующей строке после ":"
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            // Проверяем отступ (константы имеют отступ 2 пробела)
            const indent = self.countIndent();
            if (indent < 2) break; // Меньше 2 = конец секции
            if (indent > 4) {
                // Это вложенное поле, пропускаем
                self.skipToNextLine();
                continue;
            }
            self.pos += indent;

            const name = self.readKey();
            if (name.len == 0) break;

            // Проверяем что это не следующая секция (без отступа)
            if (indent == 0 and (std.mem.eql(u8, name, "types") or
                std.mem.eql(u8, name, "creation_patterns") or
                std.mem.eql(u8, name, "behaviors")))
            {
                self.pos -= name.len;
                break;
            }

            self.skipColon();

            // Пробуем прочитать inline значение (формат: NAME: VALUE)
            self.skipInlineWhitespace();
            const inline_value = self.readValue();

            var constant = Constant{
                .name = name,
                .value = 0,
                .description = "",
            };

            if (inline_value.len > 0) {
                // Inline формат: PHI: 1.618
                constant.value = std.fmt.parseFloat(f64, inline_value) catch 0;
                self.skipToNextLine();
            } else {
                // Nested формат
                self.skipToNextLine();

                // Читаем вложенные поля (отступ 4 пробела)
                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const field_indent = self.countIndent();
                    if (field_indent < 4) break; // Меньше 4 = следующая константа или конец
                    self.pos += field_indent;

                    const field_key = self.readKey();
                    if (field_key.len == 0) break;
                    self.skipColon();

                    if (std.mem.eql(u8, field_key, "value")) {
                        const value_str = self.readValue();
                        constant.value = std.fmt.parseFloat(f64, value_str) catch 0;
                    } else if (std.mem.eql(u8, field_key, "description")) {
                        constant.description = self.readQuotedValue();
                    }
                    self.skipToNextLine();
                }
            }

            try constants.append(constant);
        }
    }

    fn skipToNextLine(self: *Self) void {
        while (self.pos < self.source.len and self.source[self.pos] != '\n') {
            self.pos += 1;
        }
        if (self.pos < self.source.len) {
            self.pos += 1;
            self.line += 1;
        }
    }

    fn skipInlineWhitespace(self: *Self) void {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ' ' or c == '\t') {
                self.pos += 1;
            } else {
                break;
            }
        }
    }

    fn skipEmptyLinesAndComments(self: *Self) void {
        while (self.pos < self.source.len) {
            // Пропускаем пустые строки
            if (self.source[self.pos] == '\n') {
                self.pos += 1;
                self.line += 1;
                continue;
            }
            // Проверяем строку
            const line_start = self.pos;
            var spaces: usize = 0;
            while (self.pos < self.source.len and self.source[self.pos] == ' ') {
                spaces += 1;
                self.pos += 1;
            }
            // Пропускаем строки-комментарии
            if (self.pos < self.source.len and self.source[self.pos] == '#') {
                self.skipToNextLine();
                continue;
            }
            // Пропускаем строки только с пробелами
            if (self.pos < self.source.len and self.source[self.pos] == '\n') {
                self.pos += 1;
                self.line += 1;
                continue;
            }
            // Откатываемся к началу строки
            self.pos = line_start;
            break;
        }
    }

    fn parseTypes(self: *Self, types: *ArrayList(TypeDef)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const name = self.readKey();
            if (name.len == 0) break;

            // Проверяем что это не следующая секция
            if (std.mem.eql(u8, name, "creation_patterns") or
                std.mem.eql(u8, name, "behaviors") or
                std.mem.eql(u8, name, "algorithms") or
                std.mem.eql(u8, name, "wasm_exports"))
            {
                self.pos -= name.len + indent;
                break;
            }

            self.skipColon();
            self.skipToNextLine();

            var typedef = TypeDef.init(self.allocator);
            typedef.name = name;

            // Читаем вложенные поля
            while (self.pos < self.source.len) {
                self.skipEmptyLinesAndComments();
                if (self.pos >= self.source.len) break;

                const field_indent = self.countIndent();
                if (field_indent < 4) break;
                self.pos += field_indent;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "base")) {
                    typedef.base = self.readValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "description")) {
                    typedef.description = self.readQuotedValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "generic")) {
                    typedef.generic = self.readValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "fields")) {
                    self.skipToNextLine();
                    try self.parseFields(&typedef.fields);
                } else if (std.mem.eql(u8, field_key, "constraints")) {
                    self.skipToNextLine();
                    try self.parseConstraints(&typedef.constraints);
                } else {
                    self.skipToNextLine();
                }
            }

            try types.append(typedef);
        }
    }

    fn skipNestedBlock(self: *Self, min_indent: usize) void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;
            const indent = self.countIndent();
            if (indent <= min_indent) break;
            self.skipToNextLine();
        }
    }

    fn parseSignals(self: *Self, signals: *ArrayList(Signal)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            // Check for list item
            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1; // skip '-'
            self.skipInlineWhitespace();

            var signal = Signal{
                .name = "",
                .width = 1,
                .direction = "wire",
                .signed = false,
                .default_value = null,
            };

            // Read signal properties
            const first_key = self.readKey();
            if (std.mem.eql(u8, first_key, "name")) {
                self.skipColon();
                signal.name = self.readValue();
                self.skipToNextLine();

                // Read remaining properties
                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const prop_indent = self.countIndent();
                    if (prop_indent < 4) break;
                    self.pos += prop_indent;

                    const prop_key = self.readKey();
                    if (prop_key.len == 0) break;
                    self.skipColon();

                    if (std.mem.eql(u8, prop_key, "width")) {
                        const width_str = self.readValue();
                        signal.width = std.fmt.parseInt(u32, width_str, 10) catch 1;
                    } else if (std.mem.eql(u8, prop_key, "direction")) {
                        signal.direction = self.readValue();
                    } else if (std.mem.eql(u8, prop_key, "signed")) {
                        const val = self.readValue();
                        signal.signed = std.mem.eql(u8, val, "true");
                    } else if (std.mem.eql(u8, prop_key, "default")) {
                        const def_str = self.readValue();
                        signal.default_value = std.fmt.parseInt(i64, def_str, 10) catch null;
                    }
                    self.skipToNextLine();
                }
            } else {
                self.skipToNextLine();
                continue;
            }

            if (signal.name.len > 0) {
                try signals.append(signal);
            }
        }
    }

    fn parseReset(self: *Self, reset: *ResetDef) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;

            self.pos += indent;
            const key = self.readKey();
            if (key.len == 0) {
                self.pos -= indent;
                break;
            }

            // Check if it's a new section (no colon and standard section name)
            if (std.mem.eql(u8, key, "types") or std.mem.eql(u8, key, "behaviors") or std.mem.eql(u8, key, "algorithms")) {
                self.pos -= (indent + key.len);
                break;
            }

            self.skipColon();

            if (std.mem.eql(u8, key, "type")) {
                reset.reset_type = self.readValue();
            } else if (std.mem.eql(u8, key, "level")) {
                reset.level = self.readValue();
            }
            self.skipToNextLine();
        }
    }

    fn parseFSMs(self: *Self, fsms: *ArrayList(FSMDef)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            // Check for list item
            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1; // skip '-'
            self.skipInlineWhitespace();

            var fsm = FSMDef.init(self.allocator);

            // Read FSM properties
            const first_key = self.readKey();
            if (std.mem.eql(u8, first_key, "name")) {
                self.skipColon();
                fsm.name = self.readValue();
                self.skipToNextLine();

                // Read remaining properties
                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const prop_indent = self.countIndent();
                    if (prop_indent < 4) break;
                    self.pos += prop_indent;

                    const prop_key = self.readKey();
                    if (prop_key.len == 0) break;
                    self.skipColon();

                    if (std.mem.eql(u8, prop_key, "initial")) {
                        fsm.initial_state = self.readValue();
                        self.skipToNextLine();
                    } else if (std.mem.eql(u8, prop_key, "encoding")) {
                        fsm.encoding = self.readValue();
                        self.skipToNextLine();
                    } else if (std.mem.eql(u8, prop_key, "states")) {
                        self.skipToNextLine();
                        // Parse states list
                        while (self.pos < self.source.len) {
                            self.skipEmptyLinesAndComments();
                            if (self.pos >= self.source.len) break;

                            const state_indent = self.countIndent();
                            if (state_indent < 6) break;
                            self.pos += state_indent;

                            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                                self.pos -= state_indent;
                                break;
                            }
                            self.pos += 1; // skip '-'
                            self.skipInlineWhitespace();

                            const state_name = self.readValue();
                            if (state_name.len > 0) {
                                try fsm.states.append(state_name);
                            }
                            self.skipToNextLine();
                        }
                    } else if (std.mem.eql(u8, prop_key, "transitions")) {
                        self.skipToNextLine();
                        try self.parseFSMTransitions(&fsm.transitions);
                    } else if (std.mem.eql(u8, prop_key, "outputs")) {
                        self.skipToNextLine();
                        try self.parseFSMOutputs(&fsm.outputs);
                    } else if (std.mem.eql(u8, prop_key, "timers")) {
                        self.skipToNextLine();
                        try self.parseFSMTimers(&fsm.timers);
                    } else {
                        self.skipToNextLine();
                    }
                }
            } else {
                self.skipToNextLine();
                continue;
            }

            if (fsm.name.len > 0) {
                try fsms.append(fsm);
            }
        }
    }

    fn parseFSMTransitions(self: *Self, transitions: *ArrayList(FSMTransition)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 6) break;
            self.pos += indent;

            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1; // skip '-'
            self.skipInlineWhitespace();

            var trans = FSMTransition{
                .from_state = "",
                .to_state = "",
                .condition = "",
            };

            // Read first key (should be 'from')
            const first_key = self.readKey();
            if (std.mem.eql(u8, first_key, "from")) {
                self.skipColon();
                trans.from_state = self.readValue();
                self.skipToNextLine();

                // Read remaining properties
                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const prop_indent = self.countIndent();
                    if (prop_indent < 8) break;
                    self.pos += prop_indent;

                    const prop_key = self.readKey();
                    if (prop_key.len == 0) break;
                    self.skipColon();

                    if (std.mem.eql(u8, prop_key, "to")) {
                        trans.to_state = self.readValue();
                    } else if (std.mem.eql(u8, prop_key, "when") or std.mem.eql(u8, prop_key, "condition")) {
                        trans.condition = self.readQuotedValue();
                    }
                    self.skipToNextLine();
                }
            } else {
                self.skipToNextLine();
                continue;
            }

            if (trans.from_state.len > 0 and trans.to_state.len > 0) {
                try transitions.append(trans);
            }
        }
    }

    fn parseFSMOutputs(self: *Self, outputs: *ArrayList(FSMOutput)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 6) break;
            self.pos += indent;

            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1; // skip '-'
            self.skipInlineWhitespace();

            var out = FSMOutput.init(self.allocator);

            // Read first key (should be 'state')
            const first_key = self.readKey();
            if (std.mem.eql(u8, first_key, "state")) {
                self.skipColon();
                out.state = self.readValue();
                self.skipToNextLine();

                // Read output signal values (any key except 'state')
                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const prop_indent = self.countIndent();
                    if (prop_indent < 8) break;
                    self.pos += prop_indent;

                    const prop_key = self.readKey();
                    if (prop_key.len == 0) break;
                    self.skipColon();

                    const val = self.readQuotedOrValue();
                    // Store any signal name -> value mapping
                    try out.signals.put(prop_key, val);
                    self.skipToNextLine();
                }
            } else {
                self.skipToNextLine();
                continue;
            }

            if (out.state.len > 0) {
                try outputs.append(out);
            }
        }
    }

    fn parseFSMTimers(self: *Self, timers: *ArrayList(FSMTimer)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 6) break;
            self.pos += indent;

            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1; // skip '-'
            self.skipInlineWhitespace();

            var timer = FSMTimer{
                .state = "",
                .timeout_constant = "",
                .timeout_value = 0,
            };

            // Read first key (should be 'state')
            const first_key = self.readKey();
            if (std.mem.eql(u8, first_key, "state")) {
                self.skipColon();
                timer.state = self.readValue();
                self.skipToNextLine();

                // Read timer properties
                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const prop_indent = self.countIndent();
                    if (prop_indent < 8) break;
                    self.pos += prop_indent;

                    const prop_key = self.readKey();
                    if (prop_key.len == 0) break;
                    self.skipColon();

                    if (std.mem.eql(u8, prop_key, "timeout_constant")) {
                        timer.timeout_constant = self.readValue();
                    } else if (std.mem.eql(u8, prop_key, "timeout_value")) {
                        const val_str = self.readValue();
                        timer.timeout_value = std.fmt.parseInt(i64, val_str, 10) catch 0;
                    }
                    self.skipToNextLine();
                }
            } else {
                self.skipToNextLine();
                continue;
            }

            if (timer.state.len > 0) {
                try timers.append(timer);
            }
        }
    }

    fn parseConstraints(self: *Self, constraints: *ArrayList([]const u8)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 6) break;
            self.pos += indent;

            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1; // skip '-'
            self.skipInlineWhitespace();

            const constraint = self.readQuotedOrValue();
            if (constraint.len > 0) {
                try constraints.append(constraint);
            }
            self.skipToNextLine();
        }
    }

    fn parseFields(self: *Self, fields: *ArrayList(Field)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 6) break;
            self.pos += indent;

            const field_name = self.readKey();
            if (field_name.len == 0) break;
            self.skipColon();

            const field_type = self.readValue();
            try fields.append(Field{
                .name = field_name,
                .type_name = field_type,
            });
            self.skipToNextLine();
        }
    }

    fn parseCreationPatterns(self: *Self, patterns: *ArrayList(CreationPattern)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const name = self.readKey();
            if (name.len == 0) break;

            // Проверяем что это не следующая секция
            if (std.mem.eql(u8, name, "behaviors") or
                std.mem.eql(u8, name, "algorithms") or
                std.mem.eql(u8, name, "wasm_exports") or
                std.mem.eql(u8, name, "types"))
            {
                self.pos -= name.len + indent;
                break;
            }

            self.skipColon();
            self.skipToNextLine();

            var pattern = CreationPattern{
                .name = name,
                .source = "",
                .transformer = "",
                .result = "",
            };

            // Читаем вложенные поля
            while (self.pos < self.source.len) {
                self.skipEmptyLinesAndComments();
                if (self.pos >= self.source.len) break;

                const field_indent = self.countIndent();
                if (field_indent < 4) break;
                self.pos += field_indent;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "source")) {
                    pattern.source = self.readQuotedOrValue();
                } else if (std.mem.eql(u8, field_key, "transformer")) {
                    pattern.transformer = self.readQuotedOrValue();
                } else if (std.mem.eql(u8, field_key, "result")) {
                    pattern.result = self.readQuotedOrValue();
                }
                self.skipToNextLine();
            }

            try patterns.append(pattern);
        }
    }

    fn parseBehaviors(self: *Self, behaviors: *ArrayList(Behavior)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            // Behaviors начинаются с '-'
            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1;
            self.skipInlineWhitespace();

            var behavior = Behavior.init(self.allocator);

            // Первое поле на той же строке: "- name: value"
            const first_key = self.readKey();
            if (first_key.len > 0) {
                self.skipColon();
                if (std.mem.eql(u8, first_key, "name")) {
                    behavior.name = self.readValue();
                }
            }
            self.skipToNextLine();

            // Читаем остальные поля behavior
            while (self.pos < self.source.len) {
                self.skipEmptyLinesAndComments();
                if (self.pos >= self.source.len) break;

                const peek_indent = self.countIndent();
                if (peek_indent < 4) break;
                self.pos += peek_indent;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "name")) {
                    behavior.name = self.readValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "given")) {
                    behavior.given = self.readQuotedOrValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "when")) {
                    behavior.when = self.readQuotedOrValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "then")) {
                    behavior.then = self.readQuotedOrValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "implementation")) {
                    behavior.implementation = self.readMultilineBlock();
                } else if (std.mem.eql(u8, field_key, "test_cases")) {
                    self.skipToNextLine();
                    try self.parseTestCases(&behavior.test_cases);
                } else {
                    self.skipToNextLine();
                }
            }

            if (behavior.name.len > 0) {
                try behaviors.append(behavior);
            }
        }
    }

    fn parseTestCases(self: *Self, test_cases: *ArrayList(TestCase)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 6) break;
            self.pos += indent;

            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1;
            self.skipInlineWhitespace();

            var test_case = TestCase{
                .name = "",
                .input = "",
                .expected = "",
                .tolerance = null,
            };

            // Первое поле на той же строке
            const first_key = self.readKey();
            if (first_key.len > 0) {
                self.skipColon();
                if (std.mem.eql(u8, first_key, "input")) {
                    test_case.input = self.readBraceValue();
                } else if (std.mem.eql(u8, first_key, "name")) {
                    test_case.name = self.readValue();
                }
            }
            self.skipToNextLine();

            // Читаем остальные поля test_case
            while (self.pos < self.source.len) {
                self.skipEmptyLinesAndComments();
                if (self.pos >= self.source.len) break;

                const field_indent = self.countIndent();
                if (field_indent < 8) break;
                self.pos += field_indent;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "name")) {
                    test_case.name = self.readValue();
                } else if (std.mem.eql(u8, field_key, "input")) {
                    test_case.input = self.readBraceValue();
                } else if (std.mem.eql(u8, field_key, "expected")) {
                    test_case.expected = self.readValue();
                } else if (std.mem.eql(u8, field_key, "tolerance")) {
                    const tol_str = self.readValue();
                    test_case.tolerance = std.fmt.parseFloat(f64, tol_str) catch null;
                }
                self.skipToNextLine();
            }

            try test_cases.append(test_case);
        }
    }

    fn parseAlgorithms(self: *Self, algorithms: *ArrayList(Algorithm)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const name = self.readKey();
            if (name.len == 0) break;

            // Check for next section
            if (std.mem.eql(u8, name, "wasm_exports") or
                std.mem.eql(u8, name, "behaviors") or
                std.mem.eql(u8, name, "pas_predictions"))
            {
                self.pos -= name.len + indent;
                break;
            }

            self.skipColon();
            self.skipToNextLine();

            var algorithm = Algorithm.init(self.allocator);
            algorithm.name = name;

            // Read nested fields
            while (self.pos < self.source.len) {
                self.skipEmptyLinesAndComments();
                if (self.pos >= self.source.len) break;

                const field_indent = self.countIndent();
                if (field_indent < 4) break;
                self.pos += field_indent;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "description")) {
                    algorithm.description = self.readQuotedOrValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "complexity")) {
                    algorithm.complexity = self.readQuotedOrValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "pattern")) {
                    algorithm.pattern = self.readValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "steps")) {
                    self.skipToNextLine();
                    try self.parseAlgorithmSteps(&algorithm.steps);
                } else if (std.mem.eql(u8, field_key, "formula")) {
                    self.skipToNextLine(); // Skip formula line
                } else {
                    self.skipToNextLine();
                }
            }

            if (algorithm.name.len > 0) {
                try algorithms.append(algorithm);
            }
        }
    }

    fn parseSteps(self: *Self, steps: *ArrayList([]const u8)) !void {
        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 6) break;

            if (self.source[self.pos] != '-') break;
            self.pos += 1;
            self.skipWhitespaceAndComments();

            const step = self.readQuotedOrValue();
            if (step.len > 0) {
                try steps.append(step);
            }
        }
    }

    fn parseAlgorithmSteps(self: *Self, steps: *ArrayList([]const u8)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 6) break;
            self.pos += indent;

            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1;
            self.skipInlineWhitespace();

            const step = self.readQuotedOrValue();
            if (step.len > 0) {
                try steps.append(step);
            }
            self.skipToNextLine();
        }
    }

    fn parseWasmExports(self: *Self, exports: *WasmExports) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const key = self.readKey();
            if (key.len == 0) break;

            // Check for next section
            if (std.mem.eql(u8, key, "pas_predictions") or
                std.mem.eql(u8, key, "behaviors") or
                std.mem.eql(u8, key, "algorithms"))
            {
                self.pos -= key.len + indent;
                break;
            }

            self.skipColon();
            self.skipToNextLine();

            if (std.mem.eql(u8, key, "functions")) {
                try self.parseWasmFunctionList(&exports.functions);
            } else if (std.mem.eql(u8, key, "memory")) {
                try self.parseWasmMemoryExports(&exports.memory);
            }
        }
    }

    fn parseWasmFunctionList(self: *Self, functions: *ArrayList([]const u8)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 4) break;
            self.pos += indent;

            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1;
            self.skipInlineWhitespace();

            const func = self.readValue();
            if (func.len > 0) {
                try functions.append(func);
            }
            self.skipToNextLine();
        }
    }

    fn parseFunctionList(self: *Self, functions: *ArrayList([]const u8)) !void {
        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 4) break;

            if (self.source[self.pos] != '-') break;
            self.pos += 1;
            self.skipWhitespaceAndComments();

            const func = self.readValue();
            if (func.len > 0) {
                try functions.append(func);
            }
        }
    }

    fn parseWasmMemoryExports(self: *Self, memory: *ArrayList(MemoryExport)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 4) break;
            self.pos += indent;

            const name = self.readKey();
            if (name.len == 0) break;
            self.skipColon();
            self.skipToNextLine();

            var mem_export = MemoryExport{
                .name = name,
                .size = 0,
                .type_name = null,
                .alignment = 8,
            };

            while (self.pos < self.source.len) {
                self.skipEmptyLinesAndComments();
                if (self.pos >= self.source.len) break;

                const field_indent = self.countIndent();
                if (field_indent < 6) break;
                self.pos += field_indent;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "size")) {
                    const size_str = self.readValue();
                    mem_export.size = std.fmt.parseInt(usize, size_str, 10) catch 0;
                } else if (std.mem.eql(u8, field_key, "type")) {
                    mem_export.type_name = self.readValue();
                } else if (std.mem.eql(u8, field_key, "alignment")) {
                    const align_str = self.readValue();
                    mem_export.alignment = std.fmt.parseInt(usize, align_str, 10) catch 8;
                }
                self.skipToNextLine();
            }

            try memory.append(mem_export);
        }
    }

    fn parseMemoryExports(self: *Self, memory: *ArrayList(MemoryExport)) !void {
        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 4) break;

            const name = self.readKey();
            if (name.len == 0) break;
            self.skipColon();

            var mem_export = MemoryExport{
                .name = name,
                .size = 0,
                .type_name = null,
                .alignment = 8,
            };

            while (self.pos < self.source.len) {
                self.skipWhitespaceAndComments();
                if (self.pos >= self.source.len) break;

                const field_indent = self.countIndent();
                if (field_indent <= 4) break;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "size")) {
                    const size_str = self.readValue();
                    mem_export.size = std.fmt.parseInt(usize, size_str, 10) catch 0;
                } else if (std.mem.eql(u8, field_key, "type")) {
                    mem_export.type_name = self.readValue();
                } else if (std.mem.eql(u8, field_key, "alignment")) {
                    const align_str = self.readValue();
                    mem_export.alignment = std.fmt.parseInt(usize, align_str, 10) catch 8;
                }
            }

            try memory.append(mem_export);
        }
    }

    fn parsePasPredictions(self: *Self, predictions: *ArrayList(PasPrediction)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            // PAS predictions start with '-'
            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1;
            self.skipInlineWhitespace();

            var prediction = PasPrediction{
                .target = "",
                .current = "",
                .predicted = "",
                .confidence = 0.0,
                .pattern = "",
                .status = null,
                .timeline = null,
            };

            // First field on same line: "- target: value"
            const first_key = self.readKey();
            if (first_key.len > 0) {
                self.skipColon();
                if (std.mem.eql(u8, first_key, "target")) {
                    prediction.target = self.readValue();
                }
            }
            self.skipToNextLine();

            // Read remaining fields
            while (self.pos < self.source.len) {
                self.skipEmptyLinesAndComments();
                if (self.pos >= self.source.len) break;

                const field_indent = self.countIndent();
                if (field_indent < 4) break;
                self.pos += field_indent;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "target")) {
                    prediction.target = self.readValue();
                } else if (std.mem.eql(u8, field_key, "current")) {
                    prediction.current = self.readQuotedOrValue();
                } else if (std.mem.eql(u8, field_key, "predicted")) {
                    prediction.predicted = self.readQuotedOrValue();
                } else if (std.mem.eql(u8, field_key, "confidence")) {
                    const conf_str = self.readValue();
                    prediction.confidence = std.fmt.parseFloat(f64, conf_str) catch 0.0;
                } else if (std.mem.eql(u8, field_key, "pattern")) {
                    prediction.pattern = self.readQuotedOrValue();
                } else if (std.mem.eql(u8, field_key, "status")) {
                    prediction.status = self.readQuotedOrValue();
                } else if (std.mem.eql(u8, field_key, "timeline")) {
                    prediction.timeline = self.readQuotedOrValue();
                }
                self.skipToNextLine();
            }

            if (prediction.target.len > 0) {
                try predictions.append(prediction);
            }
        }
    }

    // Вспомогательные функции
    fn countIndent(self: *Self) usize {
        var count: usize = 0;
        const start = self.pos;
        while (self.pos < self.source.len and self.source[self.pos] == ' ') {
            count += 1;
            self.pos += 1;
        }
        self.pos = start; // Откатываемся
        return count;
    }

    fn skipLine(self: *Self) void {
        while (self.pos < self.source.len and self.source[self.pos] != '\n') {
            self.pos += 1;
        }
        if (self.pos < self.source.len) {
            self.pos += 1;
            self.line += 1;
        }
    }

    fn skipBlock(self: *Self) void {
        // Пропускаем блок с отступом
        const base_indent = self.countIndent();
        self.skipLine();
        while (self.pos < self.source.len) {
            const indent = self.countIndent();
            if (indent <= base_indent) break;
            self.skipLine();
        }
    }

    fn readQuotedOrValue(self: *Self) []const u8 {
        self.skipWhitespaceAndComments();
        if (self.pos < self.source.len and self.source[self.pos] == '"') {
            return self.readQuotedValue();
        }
        return self.readValue();
    }

    /// Read multiline block starting with | or indented lines
    fn readMultilineBlock(self: *Self) []const u8 {
        self.skipWhitespaceAndComments();
        // Check for | indicator (YAML multiline)
        if (self.pos < self.source.len and self.source[self.pos] == '|') {
            self.pos += 1;
            self.skipToNextLine();
        }
        const start = self.pos;
        const base_indent = self.countIndent();

        // Read all lines with greater indent
        while (self.pos < self.source.len) {
            const line_start = self.pos;
            const indent = self.countIndent();
            if (indent <= base_indent and self.pos > start) {
                // End of block - return to line start
                return self.source[start..line_start];
            }
            self.skipToNextLine();
        }
        return self.source[start..self.pos];
    }

    fn readBraceValue(self: *Self) []const u8 {
        self.skipWhitespaceAndComments();
        if (self.pos < self.source.len and self.source[self.pos] == '{') {
            const start = self.pos;
            var depth: usize = 0;
            while (self.pos < self.source.len) {
                const c = self.source[self.pos];
                if (c == '{') depth += 1;
                if (c == '}') {
                    depth -= 1;
                    if (depth == 0) {
                        self.pos += 1;
                        return self.source[start..self.pos];
                    }
                }
                self.pos += 1;
            }
            return self.source[start..self.pos];
        }
        return self.readValue();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════════════════════

test "parse simple spec" {
    const source =
        \\name: phi_core
        \\version: "24.φ"
        \\author: "Dmitrii Vasilev"
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqualStrings("phi_core", spec.name);
    try std.testing.expectEqualStrings("24.φ", spec.version);
}

test "parse types with constraints" {
    const source =
        \\name: test_spec
        \\version: "1.0"
        \\
        \\types:
        \\  PhiFloat:
        \\    base: f64
        \\    constraints:
        \\      - "value >= 0"
        \\      - "is_phi_power(value)"
        \\    description: "φ-optimized number"
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 1), spec.types.items.len);
    const typedef = spec.types.items[0];
    try std.testing.expectEqualStrings("PhiFloat", typedef.name);
    try std.testing.expectEqual(@as(usize, 2), typedef.constraints.items.len);
    try std.testing.expectEqualStrings("value >= 0", typedef.constraints.items[0]);
}

test "parse algorithms" {
    const source =
        \\name: algo_spec
        \\version: "1.0"
        \\
        \\algorithms:
        \\  phi_power_fast:
        \\    description: "Fast φ exponentiation"
        \\    complexity: "O(log n)"
        \\    pattern: D&C
        \\    steps:
        \\      - "If n = 0, return 1"
        \\      - "result = 1, base = φ"
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 1), spec.algorithms.items.len);
    const algo = spec.algorithms.items[0];
    try std.testing.expectEqualStrings("phi_power_fast", algo.name);
    try std.testing.expectEqualStrings("O(log n)", algo.complexity);
}

test "parse wasm_exports" {
    const source =
        \\name: wasm_spec
        \\version: "1.0"
        \\
        \\wasm_exports:
        \\  functions:
        \\    - phi_power
        \\    - fibonacci
        \\  memory:
        \\    global_buffer:
        \\      size: 65536
        \\      alignment: 16
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 2), spec.wasm_exports.functions.items.len);
    try std.testing.expectEqualStrings("phi_power", spec.wasm_exports.functions.items[0]);
    try std.testing.expectEqual(@as(usize, 1), spec.wasm_exports.memory.items.len);
}

test "parse pas_predictions" {
    const source =
        \\name: pas_spec
        \\version: "1.0"
        \\
        \\pas_predictions:
        \\  - target: phi_power
        \\    current: "O(n)"
        \\    predicted: "O(log n)"
        \\    confidence: 0.95
        \\    pattern: D&C
        \\    status: implemented
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 1), spec.pas_predictions.items.len);
    const pred = spec.pas_predictions.items[0];
    try std.testing.expectEqualStrings("phi_power", pred.target);
    try std.testing.expectEqualStrings("O(n)", pred.current);
    try std.testing.expectEqualStrings("O(log n)", pred.predicted);
    try std.testing.expect(pred.confidence > 0.9);
}

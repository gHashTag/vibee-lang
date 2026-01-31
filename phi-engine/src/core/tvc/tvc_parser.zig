const std = @import("std");
const tvc_ir = @import("tvc_ir.zig");

// TVC Parser - Converts .vibee specifications to TVC Intermediate Representation

pub const ParseError = error{
    InvalidSyntax,
    MissingField,
    UnknownType,
    ParseError,
    OutOfMemory,
};

pub const TVCParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TVCParser {
        return TVCParser{ .allocator = allocator };
    }

    pub fn parseVibeeSpec(self: *TVCParser, spec_path: []const u8) !*tvc_ir.TVCModule {
        const file = try std.fs.cwd().openFile(spec_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
        defer self.allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');

        var module_name: []const u8 = "untitled";
        var module = try self.allocator.create(tvc_ir.TVCModule);
        module.* = undefined;

        var in_behaviors = false;
        var in_types = false;

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            if (std.mem.startsWith(u8, trimmed, "name:")) {
                module_name = try self.allocator.dupe(u8, std.mem.trim(u8, trimmed["name:".len..], &std.ascii.whitespace));
                module = try self.allocator.create(tvc_ir.TVCModule);
                module.* = tvc_ir.TVCModule.init(self.allocator, module_name);
            } else if (std.mem.startsWith(u8, trimmed, "behaviors:")) {
                in_behaviors = true;
                in_types = false;
            } else if (std.mem.startsWith(u8, trimmed, "types:")) {
                in_types = true;
                in_behaviors = false;
            } else if (std.mem.startsWith(u8, trimmed, "  - name:")) {
                if (in_behaviors) {
                    const name = std.mem.trim(u8, trimmed["  - name:".len..], &std.ascii.whitespace);
                    try self.parseBehavior(module, name, &lines);
                } else if (in_types) {
                    try self.parseType(module, trimmed, &lines);
                }
            }
        }

        return module;
    }

    const BehaviorContext = struct {
        name: []const u8,
        given: []const u8 = "",
        when: []const u8 = "",
        then: []const u8 = "",
        description: []const u8 = "",
    };

    fn parseBehavior(self: *TVCParser, module: *tvc_ir.TVCModule, name: []const u8, lines: *std.mem.SplitIterator(u8, .scalar)) !void {
        var ctx = BehaviorContext{ .name = name };

        while (lines.peek()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0 or !std.mem.startsWith(u8, trimmed, "    ")) break;
            _ = lines.next();

            if (std.mem.startsWith(u8, trimmed, "given:")) {
                ctx.given = try self.allocator.dupe(u8, trimmed["given:".len..]);
            } else if (std.mem.startsWith(u8, trimmed, "when:")) {
                ctx.when = try self.allocator.dupe(u8, trimmed["when:".len..]);
            } else if (std.mem.startsWith(u8, trimmed, "then:")) {
                ctx.then = try self.allocator.dupe(u8, trimmed["then:".len..]);
            } else if (std.mem.startsWith(u8, trimmed, "description:")) {
                ctx.description = try self.allocator.dupe(u8, trimmed["description:".len..]);
            }
        }

        // Generate TVC function from behavior
        try self.generateBehaviorFunction(module, &ctx);
    }

    fn generateBehaviorFunction(self: *TVCParser, module: *tvc_ir.TVCModule, ctx: *const BehaviorContext) !void {
        const func = try module.addFunction(ctx.name);

        // Create entry block
        const block_name = try std.fmt.allocPrint(self.allocator, "{s}_entry", .{ctx.name});
        var block = tvc_ir.TVCBlock.init(self.allocator, block_name);
        block.entry_point = 0;

        // Add trinary logic operations based on behavior type
        const return_type = try self.inferReturnType(ctx.then);

        if (std.mem.indexOf(u8, ctx.name, "deduce") != null or
            std.mem.indexOf(u8, ctx.name, "induce") != null or
            std.mem.indexOf(u8, ctx.name, "abduce") != null)
        {
            // Trinary deduction operations
            try self.emitTrinaryDeduction(&block, ctx);
        } else if (std.mem.indexOf(u8, ctx.name, "verify") != null) {
            // Trinary verification
            try self.emitTrinaryVerification(&block, ctx);
        } else if (std.mem.indexOf(u8, ctx.name, "query") != null or
            std.mem.indexOf(u8, ctx.name, "update") != null)
        {
            // Knowledge base operations
            try self.emitKBOperations(&block, ctx);
        } else {
            // Generic behavior
            try self.emitGenericBehavior(&block, ctx);
        }

        // Add return instruction
        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .ret,
            .operands = &[_]u64{},
            .location = @intCast(block.instructions.items.len),
        });

        block.exit_point = @intCast(block.instructions.items.len - 1);

        try func.blocks.put(block_name, block);

        func.returns = return_type;
        func.is_extern = false;
    }

    fn emitTrinaryDeduction(self: *TVCParser, block: *tvc_ir.TVCBlock, ctx: *const BehaviorContext) !void {
        _ = self;
        _ = ctx;
    
        _ = self;
        _ = ctx;

        // Emit trinary NOT operation
        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .t_not,
            .operands = &[_]u64{0},
            .location = @intCast(block.instructions.items.len),
        });

        // Emit trinary AND operation
        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .t_and,
            .operands = &[_]u64{ 1, 2 },
            .location = @intCast(block.instructions.items.len),
        });

        // Emit trinary OR operation
        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .t_or,
            .operands = &[_]u64{ 3, 4 },
            .location = @intCast(block.instructions.items.len),
        });
    }

    fn emitTrinaryVerification(self: *TVCParser, block: *tvc_ir.TVCBlock, ctx: *const BehaviorContext) !void {
        _ = self;
        _ = ctx;

        // Load premises
        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .load,
            .operands = &[_]u64{0},
            .location = @intCast(block.instructions.items.len),
        });

        // Trinary implication check
        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .t_implies,
            .operands = &[_]u64{ 1, 2 },
            .location = @intCast(block.instructions.items.len),
        });

        // Conditional return based on trinary result
        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .jump_if,
            .operands = &[_]u64{ 3, 10 },
            .location = @intCast(block.instructions.items.len),
        });
    }

    fn emitKBOperations(self: *TVCParser, block: *tvc_ir.TVCBlock, ctx: *const BehaviorContext) !void {
        _ = self;
        _ = ctx;

        // Allocate KB structure
        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .alloc,
            .operands = &[_]u64{256},
            .location = @intCast(block.instructions.items.len),
        });

        // Store fact
        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .store,
            .operands = &[_]u64{ 0, 1 },
            .location = @intCast(block.instructions.items.len),
        });

        // Call lookup function
        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .call,
            .operands = &[_]u64{0x100},
            .location = @intCast(block.instructions.items.len),
        });
    }

    fn emitGenericBehavior(self: *TVCParser, block: *tvc_ir.TVCBlock, ctx: *const BehaviorContext) !void {
        _ = self;
        _ = ctx;

        // Simple load/store sequence
        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .load,
            .operands = &[_]u64{0},
            .location = @intCast(block.instructions.items.len),
        });

        try block.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .nop,
            .operands = &[_]u64{},
            .location = @intCast(block.instructions.items.len),
        });
    }

    fn inferReturnType(self: *TVCParser, then_clause: []const u8) !tvc_ir.TVCType {
        _ = self;

        if (std.mem.indexOf(u8, then_clause, "inference") != null) {
            return .i64_trit;
        } else if (std.mem.indexOf(u8, then_clause, "result") != null) {
            return .struct_trit;
        } else if (std.mem.indexOf(u8, then_clause, "plan") != null) {
            return .struct_trit;
        } else if (std.mem.indexOf(u8, then_clause, "Bool") != null) {
            return .i64_trit;
        }

        return .unknown;
    }

    fn parseType(self: *TVCParser, module: *tvc_ir.TVCModule, line: []const u8, lines: *std.mem.SplitIterator(u8, .scalar)) !void {
        _ = self;
        _ = module;
        _ = lines;
        _ = line;
        // TODO: Implement type parsing
    }
};

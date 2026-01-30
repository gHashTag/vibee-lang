const std = @import("std");
const tvc_ir = @import("tvc_ir.zig");

// TVC Binary Code Generator - Targets binary architectures (x86_64, ARM64, WASM)

pub const BinaryTarget = enum {
    x86_64,
    arm64,
    wasm,
};

pub const BinaryEmitter = struct {
    allocator: std.mem.Allocator,
    target: BinaryTarget,
    output: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, target: BinaryTarget) BinaryEmitter {
        return BinaryEmitter{
            .allocator = allocator,
            .target = target,
            .output = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn emitModule(self: *BinaryEmitter, module: *const tvc_ir.TVCModule) ![]const u8 {
        // Emit header based on target
        try self.emitHeader();

        // Emit all functions
        var iter = module.functions.iterator();
        while (iter.next()) |entry| {
            try self.emitFunction(entry.value_ptr.*);
        }

        // Emit footer
        try self.emitFooter();

        return self.allocator.dupe(u8, self.output.items);
    }

    fn emitHeader(self: *BinaryEmitter) !void {
        switch (self.target) {
            .x86_64 => {
                // ELF64 header for x86_64
                try self.output.appendSlice(&[8]u8{ 0x7F, 'E', 'L', 'F', 2, 1, 1, 0 });
                try self.padTo(64); // Pad to full header size
            },
            .arm64 => {
                // ARM64 magic number
                try self.output.appendSlice(&[4]u8{ 0x64, 0x65, 0x66, 0x78 });
                try self.padTo(64);
            },
            .wasm => {
                // WASM magic number and version
                try self.output.appendSlice(&[4]u8{ 0x00, 'a', 's', 'm' });
                try self.output.appendSlice(&[4]u8{ 0x01, 0x00, 0x00, 0x00 });
            },
        }
    }

    fn emitFunction(self: *BinaryEmitter, func: tvc_ir.TVCFunction) !void {
        // Emit function prologue
        try self.emitPrologue(func);

        // Emit all blocks in order
        var iter = func.blocks.iterator();
        while (iter.next()) |entry| {
            try self.emitBlock(entry.value_ptr.*);
        }

        // Emit function epilogue
        try self.emitEpilogue(func);
    }

    fn emitPrologue(self: *BinaryEmitter, func: tvc_ir.TVCFunction) !void {
        _ = func;

        switch (self.target) {
            .x86_64 => {
                // x86_64 function prologue
                try self.output.append(0x55); // push rbp
                try self.output.append(0x48); // rex.w
                try self.output.append(0x89); // mov
                try self.output.append(0xE5); // rbp, rsp
            },
            .arm64 => {
                // ARM64 function prologue
                // stp x29, x30, [sp, #-16]!
                try self.output.appendSlice(&[4]u8{ 0xFD, 0x7B, 0xBF, 0xA9 });
            },
            .wasm => {
                // WASM function header
                try self.output.append(0x03); // Function section
            },
        }
    }

    fn emitBlock(self: *BinaryEmitter, block: tvc_ir.TVCBlock) !void {
        // Emit all instructions in the block
        for (block.instructions.items) |inst| {
            try self.emitInstruction(inst);
        }
    }

    fn emitInstruction(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        switch (inst.opcode) {
            .t_not => try self.emitTrinaryNot(inst),
            .t_and => try self.emitTrinaryAnd(inst),
            .t_or => try self.emitTrinaryOr(inst),
            .t_xor => try self.emitTrinaryXor(inst),
            .t_implies => try self.emitTrinaryImplies(inst),
            .add => try self.emitAdd(inst),
            .sub => try self.emitSub(inst),
            .mul => try self.emitMul(inst),
            .div => try self.emitDiv(inst),
            .load => try self.emitLoad(inst),
            .store => try self.emitStore(inst),
            .call => try self.emitCall(inst),
            .ret => try self.emitRet(inst),
            .jump => try self.emitJump(inst),
            .jump_if => try self.emitJumpIf(inst),
            .nop => try self.emitNop(inst),
            else => try self.emitGeneric(inst),
        }
    }

    // Trinary Logic Operations (mapped to binary)
    fn emitTrinaryNot(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // TVC: trit NOT → Binary: XOR with immediate
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[4]u8{ 0x48, 0x35, 0x01, 0x00 }); // xor rax, 1
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x20, 0x1C, 0x00, 0xB2 }); // eor x0, x0, #1
            },
            .wasm => {
                try self.output.append(0x71); // i32.const 1
                try self.output.appendSlice(&[2]u8{ 0x71, 0x73 }); // i32.xor
            },
        }
    }

    fn emitTrinaryAnd(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // TVC: trit AND → Binary: AND operation
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[3]u8{ 0x48, 0x21, 0xC8 }); // and rax, rcx
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x00, 0x00, 0x8A }); // and x0, x0, x1
            },
            .wasm => {
                try self.output.append(0x71); // i32.and
            },
        }
    }

    fn emitTrinaryOr(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // TVC: trit OR → Binary: OR operation
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[3]u8{ 0x48, 0x09, 0xC8 }); // or rax, rcx
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x00, 0x40, 0xAA }); // orr x0, x0, x1
            },
            .wasm => {
                try self.output.append(0x72); // i32.or
            },
        }
    }

    fn emitTrinaryXor(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // TVC: trit XOR → Binary: XOR operation
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[3]u8{ 0x48, 0x31, 0xC8 }); // xor rax, rcx
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x00, 0x00, 0xCA }); // eor x0, x0, x1
            },
            .wasm => {
                try self.output.append(0x73); // i32.xor
            },
        }
    }

    fn emitTrinaryImplies(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // TVC: trit IMPLIES → Binary: !(A && !B)
        switch (self.target) {
            .x86_64 => {
                // NOT operand 2
                try self.output.appendSlice(&[4]u8{ 0x48, 0xF7, 0xD1 }); // not rcx
                // AND with operand 1
                try self.output.appendSlice(&[3]u8{ 0x48, 0x21, 0xC8 }); // and rax, rcx
                // NOT result
                try self.output.appendSlice(&[3]u8{ 0x48, 0xF7, 0xD0 }); // not rax
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x3F, 0x00, 0x00, 0xD2 }); // mvn x1, x1
                try self.output.appendSlice(&[4]u8{ 0x00, 0x00, 0x00, 0x8A }); // and x0, x0, x1
                try self.output.appendSlice(&[4]u8{ 0x3F, 0x00, 0x00, 0xD2 }); // mvn x0, x0
            },
            .wasm => {
                try self.output.append(0x45); // i32.eqz
                try self.output.appendSlice(&[2]u8{ 0x71, 0x72 }); // i32.and
                try self.output.append(0x45); // i32.eqz
            },
        }
    }

    // Arithmetic Operations
    fn emitAdd(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[3]u8{ 0x48, 0x01, 0xC8 }); // add rax, rcx
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x00, 0x00, 0x8B }); // add x0, x0, x1
            },
            .wasm => {
                try self.output.append(0x6A); // i32.add
            },
        }
    }

    fn emitSub(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[3]u8{ 0x48, 0x29, 0xC8 }); // sub rax, rcx
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x00, 0x00, 0xCB }); // sub x0, x0, x1
            },
            .wasm => {
                try self.output.append(0x6B); // i32.sub
            },
        }
    }

    fn emitMul(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[3]u8{ 0x48, 0x0F, 0xAF }); // imul rax, rcx
                try self.output.append(0xC1);
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x7C, 0x00, 0x9B }); // mul x0, x0, x1
            },
            .wasm => {
                try self.output.append(0x6C); // i32.mul
            },
        }
    }

    fn emitDiv(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[2]u8{ 0x48, 0x99 }); // cqo
                try self.output.appendSlice(&[3]u8{ 0x48, 0xF7, 0xF1 }); // idiv rcx
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x7C, 0x00, 0x9B }); // mul x0, x0, x1
                // Division requires more complex ARM64 code
            },
            .wasm => {
                try self.output.append(0x6D); // i32.div_s
            },
        }
    }

    // Memory Operations
    fn emitLoad(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[4]u8{ 0x48, 0x8B, 0x04, 0x25 }); // mov rax, [imm32]
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x00, 0x40, 0xF9 }); // ldr x0, [x0]
            },
            .wasm => {
                try self.output.append(0x28); // i32.load
            },
        }
    }

    fn emitStore(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[4]u8{ 0x48, 0x89, 0x04, 0x25 }); // mov [imm32], rax
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x00, 0x00, 0xF9 }); // str x0, [x1]
            },
            .wasm => {
                try self.output.append(0x36); // i32.store
            },
        }
    }

    // Control Flow
    fn emitCall(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[2]u8{ 0xE8, 0x00 }); // call rel32
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x00, 0x00, 0x94 }); // bl #imm26
            },
            .wasm => {
                try self.output.append(0x10); // call
            },
        }
    }

    fn emitRet(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[2]u8{ 0x5D, 0xC3 }); // pop rbp; ret
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0xFD, 0x7B, 0xC9, 0xA8 }); // ldp x29, x30, [sp], #16
                try self.output.appendSlice(&[4]u8{ 0xC0, 0x03, 0x5F, 0xD6 }); // ret
            },
            .wasm => {
                try self.output.append(0x0F); // end
            },
        }
    }

    fn emitJump(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[2]u8{ 0xE9, 0x00 }); // jmp rel32
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x00, 0x00, 0x14 }); // b #imm26
            },
            .wasm => {
                try self.output.append(0x0C); // br
            },
        }
    }

    fn emitJumpIf(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[4]u8{ 0x48, 0x85, 0xC0, 0x75 }); // test rax, rax; jnz
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x00, 0x00, 0x00, 0xB5 }); // cbnz x0, #imm19
            },
            .wasm => {
                try self.output.appendSlice(&[2]u8{ 0x71, 0x0D }); // i32.const 1; br_if
            },
        }
    }

    fn emitNop(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        switch (self.target) {
            .x86_64 => {
                try self.output.append(0x90); // nop
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0x1F, 0x20, 0x03, 0xD5 }); // nop
            },
            .wasm => {
                try self.output.append(0x01); // nop
            },
        }
    }

    fn emitGeneric(self: *BinaryEmitter, inst: tvc_ir.TVCInstruction) !void {
        _ = self;
        _ = inst;
        std.debug.print("Warning: Unhandled opcode\n", .{});
    }

    fn emitEpilogue(self: *BinaryEmitter, func: tvc_ir.TVCFunction) !void {
        _ = func;

        switch (self.target) {
            .x86_64 => {
                try self.output.appendSlice(&[2]u8{ 0x5D, 0xC3 }); // pop rbp; ret
            },
            .arm64 => {
                try self.output.appendSlice(&[4]u8{ 0xFD, 0x7B, 0xC9, 0xA8 }); // ldp x29, x30, [sp], #16
                try self.output.appendSlice(&[4]u8{ 0xC0, 0x03, 0x5F, 0xD6 }); // ret
            },
            .wasm => {
                try self.output.append(0x0B); // end
            },
        }
    }

    fn emitFooter(self: *BinaryEmitter) !void {
        // Emit any trailing data or fixups
        _ = self;
    }

    fn padTo(self: *BinaryEmitter, size: usize) !void {
        while (self.output.items.len < size) {
            try self.output.append(0x00);
        }
    }
};

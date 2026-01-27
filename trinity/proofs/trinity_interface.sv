// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CORE SYSTEMVERILOG INTERFACE
// ═══════════════════════════════════════════════════════════════════════════════
// This interface defines the contract between the Coptic Compiler's output
// and the physical silicon implementation (or Golden Model).
// ═══════════════════════════════════════════════════════════════════════════════

interface trinity_core_if (input logic clk, input logic rst_n);

    // --------------------------------------------------------------------------
    // Types (representing Balanced Ternary)
    // --------------------------------------------------------------------------
    typedef enum logic [1:0] {
        TRIT_N = 2'b10, // -1
        TRIT_Z = 2'b00, //  0
        TRIT_P = 2'b01  // +1
    } trit_t;

    // --------------------------------------------------------------------------
    // Signals
    // --------------------------------------------------------------------------
    // Instruction Bus (32-bit width for now, ternary-encoded internally)
    logic [31:0] instruction;
    logic        instr_valid;
    
    // Data Bus (Memory Interface)
    logic [63:0] addr;
    logic [63:0] wdata;
    logic [63:0] rdata;
    logic        mem_req;
    logic        mem_we;    // Write Enable
    logic        mem_ack;   // Acknowledge

    // Status Signals
    logic        executing;
    logic        exception;
    
    // Sacred Constants Check (Simulation Only)
    logic [63:0] phi_value;
    
    // --------------------------------------------------------------------------
    // Modports
    // --------------------------------------------------------------------------
    // View as seen by the Core
    modport core (
        input  clk, rst_n, instruction, instr_valid, rdata, mem_ack,
        output addr, wdata, mem_req, mem_we, executing, exception
    );

    // View as seen by the Testbench / Golden Model
    modport testbench (
        input  clk, rst_n, addr, wdata, mem_req, mem_we, executing, exception, phi_value,
        output instruction, instr_valid, rdata, mem_ack
    );

    // --------------------------------------------------------------------------
    // Assertions (Proof of Correctness)
    // --------------------------------------------------------------------------
    // Verify that reset clears execution state
    property p_reset_behavior;
        @(posedge clk) !rst_n |-> !executing;
    endproperty
    
    assert_reset: assert property(p_reset_behavior)
        else $error("Trinity Interface: Reset violation");

endinterface : trinity_core_if

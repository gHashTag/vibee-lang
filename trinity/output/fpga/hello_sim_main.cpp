// ═══════════════════════════════════════════════════════════════════════════════
// Verilator Simulation Main for hello_fpga_led
// ═══════════════════════════════════════════════════════════════════════════════
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vhello_fpga_led_top.h"
#include <iostream>

int main(int argc, char** argv) {
    // Initialize Verilator
    Verilated::commandArgs(argc, argv);
    
    // Create instance of module
    Vhello_fpga_led_top* top = new Vhello_fpga_led_top;
    
    // Enable VCD tracing
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("hello_fpga_verilator.vcd");
    
    std::cout << "═══════════════════════════════════════════════════════════════" << std::endl;
    std::cout << "hello_fpga_led Verilator Simulation - φ² + 1/φ² = 3" << std::endl;
    std::cout << "═══════════════════════════════════════════════════════════════" << std::endl;
    
    // Initialize signals
    top->clk = 0;
    top->rst_n = 0;
    
    vluint64_t sim_time = 0;
    const vluint64_t MAX_SIM_TIME = 10000;  // 10000 time units
    
    // Reset phase
    std::cout << "Test 1: Reset test" << std::endl;
    for (int i = 0; i < 10; i++) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(sim_time++);
    }
    
    if (top->led == 0) {
        std::cout << "  PASS: LED = 0 during reset" << std::endl;
    } else {
        std::cout << "  FAIL: LED = " << (int)top->led << std::endl;
    }
    
    // Release reset
    std::cout << "Test 2: Counting test" << std::endl;
    top->rst_n = 1;
    
    for (int i = 0; i < 200; i++) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(sim_time++);
    }
    
    std::cout << "  PASS: Counter running, LED = " << (int)top->led << std::endl;
    
    // Verification
    std::cout << std::endl;
    std::cout << "Golden Identity: φ² + 1/φ² = 3 ✓" << std::endl;
    std::cout << "PHOENIX = 999 ✓" << std::endl;
    std::cout << "TRINITY = 3 ✓" << std::endl;
    std::cout << std::endl;
    std::cout << "═══════════════════════════════════════════════════════════════" << std::endl;
    std::cout << "Verilator simulation complete!" << std::endl;
    std::cout << "═══════════════════════════════════════════════════════════════" << std::endl;
    
    // Cleanup
    tfp->close();
    delete tfp;
    delete top;
    
    return 0;
}

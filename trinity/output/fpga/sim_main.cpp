#include "Vbitnet_simd_core_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Vbitnet_simd_core_top* top = new Vbitnet_simd_core_top;
    VerilatedVcdC* tfp = new VerilatedVcdC;
    
    top->trace(tfp, 99);  // Trace 99 levels of hierarchy
    tfp->open("waveform.vcd");

    top->clk = 0;
    top->rst_n = 0;
    top->valid_in = 0;
    top->data_in = 0;

    // Simulation loop
    for (int i = 0; i < 200; i++) {
        // Toggle clock
        top->clk = !top->clk;
        
        // Reset logic
        if (i < 10) {
            top->rst_n = 0;
        } else {
            top->rst_n = 1;
        }

        // Stimulus
        if (i == 20) {
            top->valid_in = 1;
            top->data_in = 0x12345678; // Random data
        } else {
            top->valid_in = 0;
        }

        top->eval();
        tfp->dump(i * 5); // Time step
    }

    tfp->close();
    delete top;
    return 0;
}

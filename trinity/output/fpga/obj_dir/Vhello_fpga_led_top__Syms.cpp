// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vhello_fpga_led_top__pch.h"
#include "Vhello_fpga_led_top.h"
#include "Vhello_fpga_led_top___024root.h"

// FUNCTIONS
Vhello_fpga_led_top__Syms::~Vhello_fpga_led_top__Syms()
{
}

Vhello_fpga_led_top__Syms::Vhello_fpga_led_top__Syms(VerilatedContext* contextp, const char* namep, Vhello_fpga_led_top* modelp)
    : VerilatedSyms{contextp}
    // Setup internal state of the Syms class
    , __Vm_modelp{modelp}
    // Setup module instances
    , TOP{this, namep}
{
    // Configure time unit / time precision
    _vm_contextp__->timeunit(-9);
    _vm_contextp__->timeprecision(-12);
    // Setup each module's pointers to their submodules
    // Setup each module's pointer back to symbol table (for public functions)
    TOP.__Vconfigure(true);
}

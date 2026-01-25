// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vtrit_or__pch.h"
#include "Vtrit_or.h"
#include "Vtrit_or___024root.h"

// FUNCTIONS
Vtrit_or__Syms::~Vtrit_or__Syms()
{
}

Vtrit_or__Syms::Vtrit_or__Syms(VerilatedContext* contextp, const char* namep, Vtrit_or* modelp)
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

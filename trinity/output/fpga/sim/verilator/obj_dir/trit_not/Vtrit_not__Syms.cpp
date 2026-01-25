// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vtrit_not__pch.h"
#include "Vtrit_not.h"
#include "Vtrit_not___024root.h"

// FUNCTIONS
Vtrit_not__Syms::~Vtrit_not__Syms()
{
}

Vtrit_not__Syms::Vtrit_not__Syms(VerilatedContext* contextp, const char* namep, Vtrit_not* modelp)
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

// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtrit_and.h for the primary calling header

#include "Vtrit_and__pch.h"
#include "Vtrit_and__Syms.h"
#include "Vtrit_and___024root.h"

void Vtrit_and___024root___ctor_var_reset(Vtrit_and___024root* vlSelf);

Vtrit_and___024root::Vtrit_and___024root(Vtrit_and__Syms* symsp, const char* v__name)
    : VerilatedModule{v__name}
    , vlSymsp{symsp}
 {
    // Reset structure values
    Vtrit_and___024root___ctor_var_reset(this);
}

void Vtrit_and___024root::__Vconfigure(bool first) {
    if (false && first) {}  // Prevent unused
}

Vtrit_and___024root::~Vtrit_and___024root() {
}

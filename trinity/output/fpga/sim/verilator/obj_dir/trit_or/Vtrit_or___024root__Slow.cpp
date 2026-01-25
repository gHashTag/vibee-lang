// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtrit_or.h for the primary calling header

#include "Vtrit_or__pch.h"
#include "Vtrit_or__Syms.h"
#include "Vtrit_or___024root.h"

void Vtrit_or___024root___ctor_var_reset(Vtrit_or___024root* vlSelf);

Vtrit_or___024root::Vtrit_or___024root(Vtrit_or__Syms* symsp, const char* v__name)
    : VerilatedModule{v__name}
    , vlSymsp{symsp}
 {
    // Reset structure values
    Vtrit_or___024root___ctor_var_reset(this);
}

void Vtrit_or___024root::__Vconfigure(bool first) {
    if (false && first) {}  // Prevent unused
}

Vtrit_or___024root::~Vtrit_or___024root() {
}

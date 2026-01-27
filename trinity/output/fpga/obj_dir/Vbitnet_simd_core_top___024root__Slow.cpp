// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vbitnet_simd_core_top.h for the primary calling header

#include "Vbitnet_simd_core_top__pch.h"

void Vbitnet_simd_core_top___024root___ctor_var_reset(Vbitnet_simd_core_top___024root* vlSelf);

Vbitnet_simd_core_top___024root::Vbitnet_simd_core_top___024root(Vbitnet_simd_core_top__Syms* symsp, const char* namep)
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vbitnet_simd_core_top___024root___ctor_var_reset(this);
}

void Vbitnet_simd_core_top___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vbitnet_simd_core_top___024root::~Vbitnet_simd_core_top___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}

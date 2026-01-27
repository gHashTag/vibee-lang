// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vbitnet_simd_core_top.h for the primary calling header

#ifndef VERILATED_VBITNET_SIMD_CORE_TOP___024ROOT_H_
#define VERILATED_VBITNET_SIMD_CORE_TOP___024ROOT_H_  // guard

#include "verilated.h"


class Vbitnet_simd_core_top__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vbitnet_simd_core_top___024root final {
  public:

    // DESIGN SPECIFIC STATE
    VL_IN8(clk,0,0);
    VL_IN8(rst_n,0,0);
    VL_IN8(valid_in,0,0);
    VL_OUT8(valid_out,0,0);
    VL_OUT8(ready,0,0);
    CData/*2:0*/ bitnet_simd_core_top__DOT__state;
    CData/*2:0*/ bitnet_simd_core_top__DOT__next_state;
    CData/*0:0*/ __VstlFirstIteration;
    CData/*0:0*/ __VicoFirstIteration;
    CData/*0:0*/ __Vtrigprevexpr___TOP__clk__0;
    CData/*0:0*/ __Vtrigprevexpr___TOP__rst_n__0;
    VL_IN(data_in,31,0);
    VL_OUT(data_out,31,0);
    IData/*31:0*/ __VactIterCount;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vbitnet_simd_core_top__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vbitnet_simd_core_top___024root(Vbitnet_simd_core_top__Syms* symsp, const char* namep);
    ~Vbitnet_simd_core_top___024root();
    VL_UNCOPYABLE(Vbitnet_simd_core_top___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard

// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vhello_fpga_led_top.h for the primary calling header

#ifndef VERILATED_VHELLO_FPGA_LED_TOP___024ROOT_H_
#define VERILATED_VHELLO_FPGA_LED_TOP___024ROOT_H_  // guard

#include "verilated.h"


class Vhello_fpga_led_top__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vhello_fpga_led_top___024root final : public VerilatedModule {
  public:

    // DESIGN SPECIFIC STATE
    VL_IN8(clk,0,0);
    VL_IN8(rst_n,0,0);
    VL_OUT8(led,3,0);
    CData/*0:0*/ hello_fpga_led_top__DOT__led_state;
    CData/*0:0*/ __Vtrigprevexpr___TOP__clk__0;
    CData/*0:0*/ __Vtrigprevexpr___TOP__rst_n__0;
    CData/*0:0*/ __VactContinue;
    IData/*26:0*/ hello_fpga_led_top__DOT__counter;
    IData/*31:0*/ __VactIterCount;
    VlTriggerVec<1> __VactTriggered;
    VlTriggerVec<1> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vhello_fpga_led_top__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vhello_fpga_led_top___024root(Vhello_fpga_led_top__Syms* symsp, const char* v__name);
    ~Vhello_fpga_led_top___024root();
    VL_UNCOPYABLE(Vhello_fpga_led_top___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard

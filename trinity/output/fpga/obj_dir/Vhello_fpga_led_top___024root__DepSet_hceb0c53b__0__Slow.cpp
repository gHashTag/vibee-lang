// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vhello_fpga_led_top.h for the primary calling header

#include "Vhello_fpga_led_top__pch.h"
#include "Vhello_fpga_led_top___024root.h"

VL_ATTR_COLD void Vhello_fpga_led_top___024root___eval_static(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___eval_static\n"); );
}

VL_ATTR_COLD void Vhello_fpga_led_top___024root___eval_initial(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___eval_initial\n"); );
    // Body
    vlSelf->__Vtrigprevexpr___TOP__clk__0 = vlSelf->clk;
    vlSelf->__Vtrigprevexpr___TOP__rst_n__0 = vlSelf->rst_n;
}

VL_ATTR_COLD void Vhello_fpga_led_top___024root___eval_final(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___eval_final\n"); );
}

VL_ATTR_COLD void Vhello_fpga_led_top___024root___eval_settle(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___eval_settle\n"); );
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vhello_fpga_led_top___024root___dump_triggers__act(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VactTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VactTriggered.word(0U))) {
        VL_DBG_MSGF("         'act' region trigger index 0 is active: @(posedge clk or negedge rst_n)\n");
    }
}
#endif  // VL_DEBUG

#ifdef VL_DEBUG
VL_ATTR_COLD void Vhello_fpga_led_top___024root___dump_triggers__nba(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___dump_triggers__nba\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VnbaTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        VL_DBG_MSGF("         'nba' region trigger index 0 is active: @(posedge clk or negedge rst_n)\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vhello_fpga_led_top___024root___ctor_var_reset(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___ctor_var_reset\n"); );
    // Body
    vlSelf->clk = VL_RAND_RESET_I(1);
    vlSelf->rst_n = VL_RAND_RESET_I(1);
    vlSelf->led = VL_RAND_RESET_I(4);
    vlSelf->hello_fpga_led_top__DOT__counter = VL_RAND_RESET_I(27);
    vlSelf->hello_fpga_led_top__DOT__led_state = VL_RAND_RESET_I(1);
    vlSelf->__Vtrigprevexpr___TOP__clk__0 = VL_RAND_RESET_I(1);
    vlSelf->__Vtrigprevexpr___TOP__rst_n__0 = VL_RAND_RESET_I(1);
}

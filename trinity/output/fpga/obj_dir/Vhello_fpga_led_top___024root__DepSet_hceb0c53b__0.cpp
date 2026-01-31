// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vhello_fpga_led_top.h for the primary calling header

#include "Vhello_fpga_led_top__pch.h"
#include "Vhello_fpga_led_top___024root.h"

void Vhello_fpga_led_top___024root___eval_act(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___eval_act\n"); );
}

VL_INLINE_OPT void Vhello_fpga_led_top___024root___nba_sequent__TOP__0(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___nba_sequent__TOP__0\n"); );
    // Init
    CData/*0:0*/ __Vdly__hello_fpga_led_top__DOT__led_state;
    __Vdly__hello_fpga_led_top__DOT__led_state = 0;
    IData/*26:0*/ __Vdly__hello_fpga_led_top__DOT__counter;
    __Vdly__hello_fpga_led_top__DOT__counter = 0;
    // Body
    __Vdly__hello_fpga_led_top__DOT__counter = vlSelf->hello_fpga_led_top__DOT__counter;
    __Vdly__hello_fpga_led_top__DOT__led_state = vlSelf->hello_fpga_led_top__DOT__led_state;
    if (vlSelf->rst_n) {
        if ((0x2faf07fU <= vlSelf->hello_fpga_led_top__DOT__counter)) {
            __Vdly__hello_fpga_led_top__DOT__led_state 
                = (1U & (~ (IData)(vlSelf->hello_fpga_led_top__DOT__led_state)));
            __Vdly__hello_fpga_led_top__DOT__counter = 0U;
        } else {
            __Vdly__hello_fpga_led_top__DOT__counter 
                = (0x7ffffffU & ((IData)(1U) + vlSelf->hello_fpga_led_top__DOT__counter));
        }
        vlSelf->led = (0xfU & (- (IData)((IData)(vlSelf->hello_fpga_led_top__DOT__led_state))));
    } else {
        __Vdly__hello_fpga_led_top__DOT__led_state = 0U;
        __Vdly__hello_fpga_led_top__DOT__counter = 0U;
        vlSelf->led = 0U;
    }
    vlSelf->hello_fpga_led_top__DOT__counter = __Vdly__hello_fpga_led_top__DOT__counter;
    vlSelf->hello_fpga_led_top__DOT__led_state = __Vdly__hello_fpga_led_top__DOT__led_state;
}

void Vhello_fpga_led_top___024root___eval_nba(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___eval_nba\n"); );
    // Body
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vhello_fpga_led_top___024root___nba_sequent__TOP__0(vlSelf);
    }
}

void Vhello_fpga_led_top___024root___eval_triggers__act(Vhello_fpga_led_top___024root* vlSelf);

bool Vhello_fpga_led_top___024root___eval_phase__act(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___eval_phase__act\n"); );
    // Init
    VlTriggerVec<1> __VpreTriggered;
    CData/*0:0*/ __VactExecute;
    // Body
    Vhello_fpga_led_top___024root___eval_triggers__act(vlSelf);
    __VactExecute = vlSelf->__VactTriggered.any();
    if (__VactExecute) {
        __VpreTriggered.andNot(vlSelf->__VactTriggered, vlSelf->__VnbaTriggered);
        vlSelf->__VnbaTriggered.thisOr(vlSelf->__VactTriggered);
        Vhello_fpga_led_top___024root___eval_act(vlSelf);
    }
    return (__VactExecute);
}

bool Vhello_fpga_led_top___024root___eval_phase__nba(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___eval_phase__nba\n"); );
    // Init
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = vlSelf->__VnbaTriggered.any();
    if (__VnbaExecute) {
        Vhello_fpga_led_top___024root___eval_nba(vlSelf);
        vlSelf->__VnbaTriggered.clear();
    }
    return (__VnbaExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vhello_fpga_led_top___024root___dump_triggers__nba(Vhello_fpga_led_top___024root* vlSelf);
#endif  // VL_DEBUG
#ifdef VL_DEBUG
VL_ATTR_COLD void Vhello_fpga_led_top___024root___dump_triggers__act(Vhello_fpga_led_top___024root* vlSelf);
#endif  // VL_DEBUG

void Vhello_fpga_led_top___024root___eval(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___eval\n"); );
    // Init
    IData/*31:0*/ __VnbaIterCount;
    CData/*0:0*/ __VnbaContinue;
    // Body
    __VnbaIterCount = 0U;
    __VnbaContinue = 1U;
    while (__VnbaContinue) {
        if (VL_UNLIKELY((0x64U < __VnbaIterCount))) {
#ifdef VL_DEBUG
            Vhello_fpga_led_top___024root___dump_triggers__nba(vlSelf);
#endif
            VL_FATAL_MT("hello_fpga_led.v", 41, "", "NBA region did not converge.");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        __VnbaContinue = 0U;
        vlSelf->__VactIterCount = 0U;
        vlSelf->__VactContinue = 1U;
        while (vlSelf->__VactContinue) {
            if (VL_UNLIKELY((0x64U < vlSelf->__VactIterCount))) {
#ifdef VL_DEBUG
                Vhello_fpga_led_top___024root___dump_triggers__act(vlSelf);
#endif
                VL_FATAL_MT("hello_fpga_led.v", 41, "", "Active region did not converge.");
            }
            vlSelf->__VactIterCount = ((IData)(1U) 
                                       + vlSelf->__VactIterCount);
            vlSelf->__VactContinue = 0U;
            if (Vhello_fpga_led_top___024root___eval_phase__act(vlSelf)) {
                vlSelf->__VactContinue = 1U;
            }
        }
        if (Vhello_fpga_led_top___024root___eval_phase__nba(vlSelf)) {
            __VnbaContinue = 1U;
        }
    }
}

#ifdef VL_DEBUG
void Vhello_fpga_led_top___024root___eval_debug_assertions(Vhello_fpga_led_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root___eval_debug_assertions\n"); );
    // Body
    if (VL_UNLIKELY((vlSelf->clk & 0xfeU))) {
        Verilated::overWidthError("clk");}
    if (VL_UNLIKELY((vlSelf->rst_n & 0xfeU))) {
        Verilated::overWidthError("rst_n");}
}
#endif  // VL_DEBUG

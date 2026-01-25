// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtrit_half_adder.h for the primary calling header

#include "Vtrit_half_adder__pch.h"
#include "Vtrit_half_adder___024root.h"

VL_INLINE_OPT void Vtrit_half_adder___024root___ico_sequent__TOP__0(Vtrit_half_adder___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtrit_half_adder__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtrit_half_adder___024root___ico_sequent__TOP__0\n"); );
    // Init
    CData/*2:0*/ trit_half_adder__DOT__total;
    trit_half_adder__DOT__total = 0;
    // Body
    trit_half_adder__DOT__total = (7U & (((0U == (IData)(vlSelf->a))
                                           ? 7U : (
                                                   (2U 
                                                    == (IData)(vlSelf->a))
                                                    ? 1U
                                                    : 0U)) 
                                         + ((0U == (IData)(vlSelf->b))
                                             ? 7U : 
                                            ((2U == (IData)(vlSelf->b))
                                              ? 1U : 0U))));
    if ((6U == (IData)(trit_half_adder__DOT__total))) {
        vlSelf->sum = 2U;
        vlSelf->carry = 0U;
    } else {
        vlSelf->sum = ((7U == (IData)(trit_half_adder__DOT__total))
                        ? 0U : ((0U == (IData)(trit_half_adder__DOT__total))
                                 ? 1U : ((1U == (IData)(trit_half_adder__DOT__total))
                                          ? 2U : ((2U 
                                                   == (IData)(trit_half_adder__DOT__total))
                                                   ? 0U
                                                   : 1U))));
        vlSelf->carry = ((2U == (IData)(trit_half_adder__DOT__total))
                          ? 2U : 1U);
    }
}

void Vtrit_half_adder___024root___eval_ico(Vtrit_half_adder___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtrit_half_adder__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtrit_half_adder___024root___eval_ico\n"); );
    // Body
    if ((1ULL & vlSelf->__VicoTriggered.word(0U))) {
        Vtrit_half_adder___024root___ico_sequent__TOP__0(vlSelf);
    }
}

void Vtrit_half_adder___024root___eval_triggers__ico(Vtrit_half_adder___024root* vlSelf);

bool Vtrit_half_adder___024root___eval_phase__ico(Vtrit_half_adder___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtrit_half_adder__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtrit_half_adder___024root___eval_phase__ico\n"); );
    // Init
    CData/*0:0*/ __VicoExecute;
    // Body
    Vtrit_half_adder___024root___eval_triggers__ico(vlSelf);
    __VicoExecute = vlSelf->__VicoTriggered.any();
    if (__VicoExecute) {
        Vtrit_half_adder___024root___eval_ico(vlSelf);
    }
    return (__VicoExecute);
}

void Vtrit_half_adder___024root___eval_act(Vtrit_half_adder___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtrit_half_adder__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtrit_half_adder___024root___eval_act\n"); );
}

void Vtrit_half_adder___024root___eval_nba(Vtrit_half_adder___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtrit_half_adder__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtrit_half_adder___024root___eval_nba\n"); );
}

void Vtrit_half_adder___024root___eval_triggers__act(Vtrit_half_adder___024root* vlSelf);

bool Vtrit_half_adder___024root___eval_phase__act(Vtrit_half_adder___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtrit_half_adder__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtrit_half_adder___024root___eval_phase__act\n"); );
    // Init
    VlTriggerVec<0> __VpreTriggered;
    CData/*0:0*/ __VactExecute;
    // Body
    Vtrit_half_adder___024root___eval_triggers__act(vlSelf);
    __VactExecute = vlSelf->__VactTriggered.any();
    if (__VactExecute) {
        __VpreTriggered.andNot(vlSelf->__VactTriggered, vlSelf->__VnbaTriggered);
        vlSelf->__VnbaTriggered.thisOr(vlSelf->__VactTriggered);
        Vtrit_half_adder___024root___eval_act(vlSelf);
    }
    return (__VactExecute);
}

bool Vtrit_half_adder___024root___eval_phase__nba(Vtrit_half_adder___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtrit_half_adder__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtrit_half_adder___024root___eval_phase__nba\n"); );
    // Init
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = vlSelf->__VnbaTriggered.any();
    if (__VnbaExecute) {
        Vtrit_half_adder___024root___eval_nba(vlSelf);
        vlSelf->__VnbaTriggered.clear();
    }
    return (__VnbaExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtrit_half_adder___024root___dump_triggers__ico(Vtrit_half_adder___024root* vlSelf);
#endif  // VL_DEBUG
#ifdef VL_DEBUG
VL_ATTR_COLD void Vtrit_half_adder___024root___dump_triggers__nba(Vtrit_half_adder___024root* vlSelf);
#endif  // VL_DEBUG
#ifdef VL_DEBUG
VL_ATTR_COLD void Vtrit_half_adder___024root___dump_triggers__act(Vtrit_half_adder___024root* vlSelf);
#endif  // VL_DEBUG

void Vtrit_half_adder___024root___eval(Vtrit_half_adder___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtrit_half_adder__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtrit_half_adder___024root___eval\n"); );
    // Init
    IData/*31:0*/ __VicoIterCount;
    CData/*0:0*/ __VicoContinue;
    IData/*31:0*/ __VnbaIterCount;
    CData/*0:0*/ __VnbaContinue;
    // Body
    __VicoIterCount = 0U;
    vlSelf->__VicoFirstIteration = 1U;
    __VicoContinue = 1U;
    while (__VicoContinue) {
        if (VL_UNLIKELY((0x64U < __VicoIterCount))) {
#ifdef VL_DEBUG
            Vtrit_half_adder___024root___dump_triggers__ico(vlSelf);
#endif
            VL_FATAL_MT("../../ternary_logic_core.v", 258, "", "Input combinational region did not converge.");
        }
        __VicoIterCount = ((IData)(1U) + __VicoIterCount);
        __VicoContinue = 0U;
        if (Vtrit_half_adder___024root___eval_phase__ico(vlSelf)) {
            __VicoContinue = 1U;
        }
        vlSelf->__VicoFirstIteration = 0U;
    }
    __VnbaIterCount = 0U;
    __VnbaContinue = 1U;
    while (__VnbaContinue) {
        if (VL_UNLIKELY((0x64U < __VnbaIterCount))) {
#ifdef VL_DEBUG
            Vtrit_half_adder___024root___dump_triggers__nba(vlSelf);
#endif
            VL_FATAL_MT("../../ternary_logic_core.v", 258, "", "NBA region did not converge.");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        __VnbaContinue = 0U;
        vlSelf->__VactIterCount = 0U;
        vlSelf->__VactContinue = 1U;
        while (vlSelf->__VactContinue) {
            if (VL_UNLIKELY((0x64U < vlSelf->__VactIterCount))) {
#ifdef VL_DEBUG
                Vtrit_half_adder___024root___dump_triggers__act(vlSelf);
#endif
                VL_FATAL_MT("../../ternary_logic_core.v", 258, "", "Active region did not converge.");
            }
            vlSelf->__VactIterCount = ((IData)(1U) 
                                       + vlSelf->__VactIterCount);
            vlSelf->__VactContinue = 0U;
            if (Vtrit_half_adder___024root___eval_phase__act(vlSelf)) {
                vlSelf->__VactContinue = 1U;
            }
        }
        if (Vtrit_half_adder___024root___eval_phase__nba(vlSelf)) {
            __VnbaContinue = 1U;
        }
    }
}

#ifdef VL_DEBUG
void Vtrit_half_adder___024root___eval_debug_assertions(Vtrit_half_adder___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtrit_half_adder__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtrit_half_adder___024root___eval_debug_assertions\n"); );
    // Body
    if (VL_UNLIKELY((vlSelf->a & 0xfcU))) {
        Verilated::overWidthError("a");}
    if (VL_UNLIKELY((vlSelf->b & 0xfcU))) {
        Verilated::overWidthError("b");}
}
#endif  // VL_DEBUG

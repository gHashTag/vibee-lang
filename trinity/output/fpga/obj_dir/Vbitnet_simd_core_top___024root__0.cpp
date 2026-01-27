// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vbitnet_simd_core_top.h for the primary calling header

#include "Vbitnet_simd_core_top__pch.h"

#ifdef VL_DEBUG
VL_ATTR_COLD void Vbitnet_simd_core_top___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

void Vbitnet_simd_core_top___024root___eval_triggers__ico(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_triggers__ico\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VicoTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered
                                      [0U]) | (IData)((IData)(vlSelfRef.__VicoFirstIteration)));
    vlSelfRef.__VicoFirstIteration = 0U;
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vbitnet_simd_core_top___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
}

bool Vbitnet_simd_core_top___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___trigger_anySet__ico\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vbitnet_simd_core_top___024root___ico_sequent__TOP__0(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___ico_sequent__TOP__0\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.bitnet_simd_core_top__DOT__next_state 
        = vlSelfRef.bitnet_simd_core_top__DOT__state;
    if ((0U == (IData)(vlSelfRef.bitnet_simd_core_top__DOT__state))) {
        if (vlSelfRef.valid_in) {
            vlSelfRef.bitnet_simd_core_top__DOT__next_state = 1U;
        }
    } else {
        vlSelfRef.bitnet_simd_core_top__DOT__next_state 
            = ((1U == (IData)(vlSelfRef.bitnet_simd_core_top__DOT__state))
                ? 2U : 0U);
    }
}

void Vbitnet_simd_core_top___024root___eval_ico(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_ico\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VicoTriggered[0U])) {
        Vbitnet_simd_core_top___024root___ico_sequent__TOP__0(vlSelf);
    }
}

bool Vbitnet_simd_core_top___024root___eval_phase__ico(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_phase__ico\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VicoExecute;
    // Body
    Vbitnet_simd_core_top___024root___eval_triggers__ico(vlSelf);
    __VicoExecute = Vbitnet_simd_core_top___024root___trigger_anySet__ico(vlSelfRef.__VicoTriggered);
    if (__VicoExecute) {
        Vbitnet_simd_core_top___024root___eval_ico(vlSelf);
    }
    return (__VicoExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vbitnet_simd_core_top___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

void Vbitnet_simd_core_top___024root___eval_triggers__act(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_triggers__act\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                    ((((~ (IData)(vlSelfRef.rst_n)) 
                                                       & (IData)(vlSelfRef.__Vtrigprevexpr___TOP__rst_n__0)) 
                                                      << 1U) 
                                                     | ((IData)(vlSelfRef.clk) 
                                                        & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__clk__0))))));
    vlSelfRef.__Vtrigprevexpr___TOP__clk__0 = vlSelfRef.clk;
    vlSelfRef.__Vtrigprevexpr___TOP__rst_n__0 = vlSelfRef.rst_n;
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vbitnet_simd_core_top___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
}

bool Vbitnet_simd_core_top___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___trigger_anySet__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vbitnet_simd_core_top___024root___nba_sequent__TOP__0(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___nba_sequent__TOP__0\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.valid_out = ((IData)(vlSelfRef.rst_n) 
                           && (2U == (IData)(vlSelfRef.bitnet_simd_core_top__DOT__state)));
    if (vlSelfRef.rst_n) {
        if ((1U == (IData)(vlSelfRef.bitnet_simd_core_top__DOT__state))) {
            vlSelfRef.data_out = (0x000003e7U ^ vlSelfRef.data_in);
        }
        vlSelfRef.bitnet_simd_core_top__DOT__state 
            = vlSelfRef.bitnet_simd_core_top__DOT__next_state;
    } else {
        vlSelfRef.data_out = 0U;
        vlSelfRef.bitnet_simd_core_top__DOT__state = 0U;
    }
    if ((0U == (IData)(vlSelfRef.bitnet_simd_core_top__DOT__state))) {
        vlSelfRef.ready = 1U;
        vlSelfRef.bitnet_simd_core_top__DOT__next_state 
            = vlSelfRef.bitnet_simd_core_top__DOT__state;
        if (vlSelfRef.valid_in) {
            vlSelfRef.bitnet_simd_core_top__DOT__next_state = 1U;
        }
    } else {
        vlSelfRef.ready = 0U;
        vlSelfRef.bitnet_simd_core_top__DOT__next_state 
            = vlSelfRef.bitnet_simd_core_top__DOT__state;
        vlSelfRef.bitnet_simd_core_top__DOT__next_state 
            = ((1U == (IData)(vlSelfRef.bitnet_simd_core_top__DOT__state))
                ? 2U : 0U);
    }
}

void Vbitnet_simd_core_top___024root___eval_nba(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_nba\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((3ULL & vlSelfRef.__VnbaTriggered[0U])) {
        Vbitnet_simd_core_top___024root___nba_sequent__TOP__0(vlSelf);
    }
}

void Vbitnet_simd_core_top___024root___trigger_orInto__act(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___trigger_orInto__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

bool Vbitnet_simd_core_top___024root___eval_phase__act(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_phase__act\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vbitnet_simd_core_top___024root___eval_triggers__act(vlSelf);
    Vbitnet_simd_core_top___024root___trigger_orInto__act(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    return (0U);
}

void Vbitnet_simd_core_top___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___trigger_clear__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

bool Vbitnet_simd_core_top___024root___eval_phase__nba(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_phase__nba\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vbitnet_simd_core_top___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        Vbitnet_simd_core_top___024root___eval_nba(vlSelf);
        Vbitnet_simd_core_top___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

void Vbitnet_simd_core_top___024root___eval(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VicoIterCount;
    IData/*31:0*/ __VnbaIterCount;
    // Body
    __VicoIterCount = 0U;
    vlSelfRef.__VicoFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00000064U < __VicoIterCount)))) {
#ifdef VL_DEBUG
            Vbitnet_simd_core_top___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
#endif
            VL_FATAL_MT("bitnet_simd_core.v", 71, "", "Input combinational region did not converge after 100 tries");
        }
        __VicoIterCount = ((IData)(1U) + __VicoIterCount);
    } while (Vbitnet_simd_core_top___024root___eval_phase__ico(vlSelf));
    __VnbaIterCount = 0U;
    do {
        if (VL_UNLIKELY(((0x00000064U < __VnbaIterCount)))) {
#ifdef VL_DEBUG
            Vbitnet_simd_core_top___024root___dump_triggers__act(vlSelfRef.__VnbaTriggered, "nba"s);
#endif
            VL_FATAL_MT("bitnet_simd_core.v", 71, "", "NBA region did not converge after 100 tries");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        vlSelfRef.__VactIterCount = 0U;
        do {
            if (VL_UNLIKELY(((0x00000064U < vlSelfRef.__VactIterCount)))) {
#ifdef VL_DEBUG
                Vbitnet_simd_core_top___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
#endif
                VL_FATAL_MT("bitnet_simd_core.v", 71, "", "Active region did not converge after 100 tries");
            }
            vlSelfRef.__VactIterCount = ((IData)(1U) 
                                         + vlSelfRef.__VactIterCount);
        } while (Vbitnet_simd_core_top___024root___eval_phase__act(vlSelf));
    } while (Vbitnet_simd_core_top___024root___eval_phase__nba(vlSelf));
}

#ifdef VL_DEBUG
void Vbitnet_simd_core_top___024root___eval_debug_assertions(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_debug_assertions\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if (VL_UNLIKELY(((vlSelfRef.clk & 0xfeU)))) {
        Verilated::overWidthError("clk");
    }
    if (VL_UNLIKELY(((vlSelfRef.rst_n & 0xfeU)))) {
        Verilated::overWidthError("rst_n");
    }
    if (VL_UNLIKELY(((vlSelfRef.valid_in & 0xfeU)))) {
        Verilated::overWidthError("valid_in");
    }
}
#endif  // VL_DEBUG

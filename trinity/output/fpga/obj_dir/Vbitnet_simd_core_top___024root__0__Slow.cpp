// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vbitnet_simd_core_top.h for the primary calling header

#include "Vbitnet_simd_core_top__pch.h"

VL_ATTR_COLD void Vbitnet_simd_core_top___024root___eval_static(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_static\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__Vtrigprevexpr___TOP__clk__0 = vlSelfRef.clk;
    vlSelfRef.__Vtrigprevexpr___TOP__rst_n__0 = vlSelfRef.rst_n;
}

VL_ATTR_COLD void Vbitnet_simd_core_top___024root___eval_initial(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_initial\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vbitnet_simd_core_top___024root___eval_final(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_final\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vbitnet_simd_core_top___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vbitnet_simd_core_top___024root___eval_phase__stl(Vbitnet_simd_core_top___024root* vlSelf);

VL_ATTR_COLD void Vbitnet_simd_core_top___024root___eval_settle(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_settle\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VstlIterCount;
    // Body
    __VstlIterCount = 0U;
    vlSelfRef.__VstlFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00000064U < __VstlIterCount)))) {
#ifdef VL_DEBUG
            Vbitnet_simd_core_top___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
#endif
            VL_FATAL_MT("bitnet_simd_core.v", 71, "", "Settle region did not converge after 100 tries");
        }
        __VstlIterCount = ((IData)(1U) + __VstlIterCount);
    } while (Vbitnet_simd_core_top___024root___eval_phase__stl(vlSelf));
}

VL_ATTR_COLD void Vbitnet_simd_core_top___024root___eval_triggers__stl(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_triggers__stl\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VstlTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VstlTriggered
                                      [0U]) | (IData)((IData)(vlSelfRef.__VstlFirstIteration)));
    vlSelfRef.__VstlFirstIteration = 0U;
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vbitnet_simd_core_top___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
    }
#endif
}

VL_ATTR_COLD bool Vbitnet_simd_core_top___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vbitnet_simd_core_top___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(Vbitnet_simd_core_top___024root___trigger_anySet__stl(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD bool Vbitnet_simd_core_top___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___trigger_anySet__stl\n"); );
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

VL_ATTR_COLD void Vbitnet_simd_core_top___024root___stl_sequent__TOP__0(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___stl_sequent__TOP__0\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
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

VL_ATTR_COLD void Vbitnet_simd_core_top___024root___eval_stl(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_stl\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VstlTriggered[0U])) {
        Vbitnet_simd_core_top___024root___stl_sequent__TOP__0(vlSelf);
    }
}

VL_ATTR_COLD bool Vbitnet_simd_core_top___024root___eval_phase__stl(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___eval_phase__stl\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VstlExecute;
    // Body
    Vbitnet_simd_core_top___024root___eval_triggers__stl(vlSelf);
    __VstlExecute = Vbitnet_simd_core_top___024root___trigger_anySet__stl(vlSelfRef.__VstlTriggered);
    if (__VstlExecute) {
        Vbitnet_simd_core_top___024root___eval_stl(vlSelf);
    }
    return (__VstlExecute);
}

bool Vbitnet_simd_core_top___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vbitnet_simd_core_top___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (IData)(Vbitnet_simd_core_top___024root___trigger_anySet__ico(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

bool Vbitnet_simd_core_top___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vbitnet_simd_core_top___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(Vbitnet_simd_core_top___024root___trigger_anySet__act(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: @(posedge clk)\n");
    }
    if ((1U & (IData)((triggers[0U] >> 1U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 1 is active: @(negedge rst_n)\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vbitnet_simd_core_top___024root___ctor_var_reset(Vbitnet_simd_core_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root___ctor_var_reset\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
    vlSelf->clk = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 16707436170211756652ull);
    vlSelf->rst_n = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 1638864771569018232ull);
    vlSelf->data_in = VL_SCOPED_RAND_RESET_I(32, __VscopeHash, 10574596302020702150ull);
    vlSelf->valid_in = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 16540271516330450727ull);
    vlSelf->data_out = VL_SCOPED_RAND_RESET_I(32, __VscopeHash, 11675680895196038875ull);
    vlSelf->valid_out = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8744939437868816662ull);
    vlSelf->ready = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 898948264233693212ull);
    vlSelf->bitnet_simd_core_top__DOT__state = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 9077520877847055605ull);
    vlSelf->bitnet_simd_core_top__DOT__next_state = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 2830058678281246186ull);
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VstlTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VicoTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VactTriggered[__Vi0] = 0;
    }
    vlSelf->__Vtrigprevexpr___TOP__clk__0 = 0;
    vlSelf->__Vtrigprevexpr___TOP__rst_n__0 = 0;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VnbaTriggered[__Vi0] = 0;
    }
}

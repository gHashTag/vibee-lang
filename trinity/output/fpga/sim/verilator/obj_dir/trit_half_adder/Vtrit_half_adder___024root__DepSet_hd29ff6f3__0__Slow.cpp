// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtrit_half_adder.h for the primary calling header

#include "Vtrit_half_adder__pch.h"
#include "Vtrit_half_adder__Syms.h"
#include "Vtrit_half_adder___024root.h"

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtrit_half_adder___024root___dump_triggers__stl(Vtrit_half_adder___024root* vlSelf);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vtrit_half_adder___024root___eval_triggers__stl(Vtrit_half_adder___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtrit_half_adder__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtrit_half_adder___024root___eval_triggers__stl\n"); );
    // Body
    vlSelf->__VstlTriggered.set(0U, (IData)(vlSelf->__VstlFirstIteration));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtrit_half_adder___024root___dump_triggers__stl(vlSelf);
    }
#endif
}

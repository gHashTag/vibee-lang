// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals

#include "verilated_vcd_c.h"
#include "Vbitnet_simd_core_top__Syms.h"


void Vbitnet_simd_core_top___024root__trace_chg_0_sub_0(Vbitnet_simd_core_top___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vbitnet_simd_core_top___024root__trace_chg_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root__trace_chg_0\n"); );
    // Body
    Vbitnet_simd_core_top___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vbitnet_simd_core_top___024root*>(voidSelf);
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    Vbitnet_simd_core_top___024root__trace_chg_0_sub_0((&vlSymsp->TOP), bufp);
}

void Vbitnet_simd_core_top___024root__trace_chg_0_sub_0(Vbitnet_simd_core_top___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root__trace_chg_0_sub_0\n"); );
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 1);
    bufp->chgBit(oldp+0,(vlSelfRef.clk));
    bufp->chgBit(oldp+1,(vlSelfRef.rst_n));
    bufp->chgIData(oldp+2,(vlSelfRef.data_in),32);
    bufp->chgBit(oldp+3,(vlSelfRef.valid_in));
    bufp->chgIData(oldp+4,(vlSelfRef.data_out),32);
    bufp->chgBit(oldp+5,(vlSelfRef.valid_out));
    bufp->chgBit(oldp+6,(vlSelfRef.ready));
    bufp->chgCData(oldp+7,(vlSelfRef.bitnet_simd_core_top__DOT__state),3);
    bufp->chgCData(oldp+8,(vlSelfRef.bitnet_simd_core_top__DOT__next_state),3);
}

void Vbitnet_simd_core_top___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vbitnet_simd_core_top___024root__trace_cleanup\n"); );
    // Locals
    VlUnpacked<CData/*0:0*/, 1> __Vm_traceActivity;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        __Vm_traceActivity[__Vi0] = 0;
    }
    // Body
    Vbitnet_simd_core_top___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vbitnet_simd_core_top___024root*>(voidSelf);
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    vlSymsp->__Vm_activity = false;
    __Vm_traceActivity[0U] = 0U;
}

// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vhello_fpga_led_top__Syms.h"


void Vhello_fpga_led_top___024root__trace_chg_0_sub_0(Vhello_fpga_led_top___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vhello_fpga_led_top___024root__trace_chg_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root__trace_chg_0\n"); );
    // Init
    Vhello_fpga_led_top___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vhello_fpga_led_top___024root*>(voidSelf);
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vhello_fpga_led_top___024root__trace_chg_0_sub_0((&vlSymsp->TOP), bufp);
}

void Vhello_fpga_led_top___024root__trace_chg_0_sub_0(Vhello_fpga_led_top___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root__trace_chg_0_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 1);
    // Body
    bufp->chgBit(oldp+0,(vlSelf->clk));
    bufp->chgBit(oldp+1,(vlSelf->rst_n));
    bufp->chgCData(oldp+2,(vlSelf->led),4);
    bufp->chgIData(oldp+3,(vlSelf->hello_fpga_led_top__DOT__counter),27);
    bufp->chgBit(oldp+4,(vlSelf->hello_fpga_led_top__DOT__led_state));
}

void Vhello_fpga_led_top___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vhello_fpga_led_top___024root__trace_cleanup\n"); );
    // Init
    Vhello_fpga_led_top___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vhello_fpga_led_top___024root*>(voidSelf);
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VlUnpacked<CData/*0:0*/, 1> __Vm_traceActivity;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        __Vm_traceActivity[__Vi0] = 0;
    }
    // Body
    vlSymsp->__Vm_activity = false;
    __Vm_traceActivity[0U] = 0U;
}

// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtrit_half_adder__pch.h"

//============================================================
// Constructors

Vtrit_half_adder::Vtrit_half_adder(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtrit_half_adder__Syms(contextp(), _vcname__, this)}
    , a{vlSymsp->TOP.a}
    , b{vlSymsp->TOP.b}
    , sum{vlSymsp->TOP.sum}
    , carry{vlSymsp->TOP.carry}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vtrit_half_adder::Vtrit_half_adder(const char* _vcname__)
    : Vtrit_half_adder(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtrit_half_adder::~Vtrit_half_adder() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtrit_half_adder___024root___eval_debug_assertions(Vtrit_half_adder___024root* vlSelf);
#endif  // VL_DEBUG
void Vtrit_half_adder___024root___eval_static(Vtrit_half_adder___024root* vlSelf);
void Vtrit_half_adder___024root___eval_initial(Vtrit_half_adder___024root* vlSelf);
void Vtrit_half_adder___024root___eval_settle(Vtrit_half_adder___024root* vlSelf);
void Vtrit_half_adder___024root___eval(Vtrit_half_adder___024root* vlSelf);

void Vtrit_half_adder::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtrit_half_adder::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vtrit_half_adder___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vtrit_half_adder___024root___eval_static(&(vlSymsp->TOP));
        Vtrit_half_adder___024root___eval_initial(&(vlSymsp->TOP));
        Vtrit_half_adder___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vtrit_half_adder___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vtrit_half_adder::eventsPending() { return false; }

uint64_t Vtrit_half_adder::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "%Error: No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vtrit_half_adder::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vtrit_half_adder___024root___eval_final(Vtrit_half_adder___024root* vlSelf);

VL_ATTR_COLD void Vtrit_half_adder::final() {
    Vtrit_half_adder___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtrit_half_adder::hierName() const { return vlSymsp->name(); }
const char* Vtrit_half_adder::modelName() const { return "Vtrit_half_adder"; }
unsigned Vtrit_half_adder::threads() const { return 1; }
void Vtrit_half_adder::prepareClone() const { contextp()->prepareClone(); }
void Vtrit_half_adder::atClone() const {
    contextp()->threadPoolpOnClone();
}

//============================================================
// Trace configuration

VL_ATTR_COLD void Vtrit_half_adder::trace(VerilatedVcdC* tfp, int levels, int options) {
    vl_fatal(__FILE__, __LINE__, __FILE__,"'Vtrit_half_adder::trace()' called on model that was Verilated without --trace option");
}

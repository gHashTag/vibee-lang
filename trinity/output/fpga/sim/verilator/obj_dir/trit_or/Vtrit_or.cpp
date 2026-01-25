// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtrit_or__pch.h"

//============================================================
// Constructors

Vtrit_or::Vtrit_or(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtrit_or__Syms(contextp(), _vcname__, this)}
    , a{vlSymsp->TOP.a}
    , b{vlSymsp->TOP.b}
    , result{vlSymsp->TOP.result}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vtrit_or::Vtrit_or(const char* _vcname__)
    : Vtrit_or(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtrit_or::~Vtrit_or() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtrit_or___024root___eval_debug_assertions(Vtrit_or___024root* vlSelf);
#endif  // VL_DEBUG
void Vtrit_or___024root___eval_static(Vtrit_or___024root* vlSelf);
void Vtrit_or___024root___eval_initial(Vtrit_or___024root* vlSelf);
void Vtrit_or___024root___eval_settle(Vtrit_or___024root* vlSelf);
void Vtrit_or___024root___eval(Vtrit_or___024root* vlSelf);

void Vtrit_or::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtrit_or::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vtrit_or___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vtrit_or___024root___eval_static(&(vlSymsp->TOP));
        Vtrit_or___024root___eval_initial(&(vlSymsp->TOP));
        Vtrit_or___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vtrit_or___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vtrit_or::eventsPending() { return false; }

uint64_t Vtrit_or::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "%Error: No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vtrit_or::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vtrit_or___024root___eval_final(Vtrit_or___024root* vlSelf);

VL_ATTR_COLD void Vtrit_or::final() {
    Vtrit_or___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtrit_or::hierName() const { return vlSymsp->name(); }
const char* Vtrit_or::modelName() const { return "Vtrit_or"; }
unsigned Vtrit_or::threads() const { return 1; }
void Vtrit_or::prepareClone() const { contextp()->prepareClone(); }
void Vtrit_or::atClone() const {
    contextp()->threadPoolpOnClone();
}

//============================================================
// Trace configuration

VL_ATTR_COLD void Vtrit_or::trace(VerilatedVcdC* tfp, int levels, int options) {
    vl_fatal(__FILE__, __LINE__, __FILE__,"'Vtrit_or::trace()' called on model that was Verilated without --trace option");
}

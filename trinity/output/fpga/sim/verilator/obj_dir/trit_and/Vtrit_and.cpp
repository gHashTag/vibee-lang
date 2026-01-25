// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtrit_and__pch.h"

//============================================================
// Constructors

Vtrit_and::Vtrit_and(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtrit_and__Syms(contextp(), _vcname__, this)}
    , a{vlSymsp->TOP.a}
    , b{vlSymsp->TOP.b}
    , result{vlSymsp->TOP.result}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vtrit_and::Vtrit_and(const char* _vcname__)
    : Vtrit_and(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtrit_and::~Vtrit_and() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtrit_and___024root___eval_debug_assertions(Vtrit_and___024root* vlSelf);
#endif  // VL_DEBUG
void Vtrit_and___024root___eval_static(Vtrit_and___024root* vlSelf);
void Vtrit_and___024root___eval_initial(Vtrit_and___024root* vlSelf);
void Vtrit_and___024root___eval_settle(Vtrit_and___024root* vlSelf);
void Vtrit_and___024root___eval(Vtrit_and___024root* vlSelf);

void Vtrit_and::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtrit_and::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vtrit_and___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vtrit_and___024root___eval_static(&(vlSymsp->TOP));
        Vtrit_and___024root___eval_initial(&(vlSymsp->TOP));
        Vtrit_and___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vtrit_and___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vtrit_and::eventsPending() { return false; }

uint64_t Vtrit_and::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "%Error: No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vtrit_and::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vtrit_and___024root___eval_final(Vtrit_and___024root* vlSelf);

VL_ATTR_COLD void Vtrit_and::final() {
    Vtrit_and___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtrit_and::hierName() const { return vlSymsp->name(); }
const char* Vtrit_and::modelName() const { return "Vtrit_and"; }
unsigned Vtrit_and::threads() const { return 1; }
void Vtrit_and::prepareClone() const { contextp()->prepareClone(); }
void Vtrit_and::atClone() const {
    contextp()->threadPoolpOnClone();
}

//============================================================
// Trace configuration

VL_ATTR_COLD void Vtrit_and::trace(VerilatedVcdC* tfp, int levels, int options) {
    vl_fatal(__FILE__, __LINE__, __FILE__,"'Vtrit_and::trace()' called on model that was Verilated without --trace option");
}

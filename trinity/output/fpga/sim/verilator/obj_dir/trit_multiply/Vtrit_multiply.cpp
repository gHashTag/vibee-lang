// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtrit_multiply__pch.h"

//============================================================
// Constructors

Vtrit_multiply::Vtrit_multiply(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtrit_multiply__Syms(contextp(), _vcname__, this)}
    , a{vlSymsp->TOP.a}
    , b{vlSymsp->TOP.b}
    , result{vlSymsp->TOP.result}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vtrit_multiply::Vtrit_multiply(const char* _vcname__)
    : Vtrit_multiply(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtrit_multiply::~Vtrit_multiply() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtrit_multiply___024root___eval_debug_assertions(Vtrit_multiply___024root* vlSelf);
#endif  // VL_DEBUG
void Vtrit_multiply___024root___eval_static(Vtrit_multiply___024root* vlSelf);
void Vtrit_multiply___024root___eval_initial(Vtrit_multiply___024root* vlSelf);
void Vtrit_multiply___024root___eval_settle(Vtrit_multiply___024root* vlSelf);
void Vtrit_multiply___024root___eval(Vtrit_multiply___024root* vlSelf);

void Vtrit_multiply::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtrit_multiply::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vtrit_multiply___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vtrit_multiply___024root___eval_static(&(vlSymsp->TOP));
        Vtrit_multiply___024root___eval_initial(&(vlSymsp->TOP));
        Vtrit_multiply___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vtrit_multiply___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vtrit_multiply::eventsPending() { return false; }

uint64_t Vtrit_multiply::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "%Error: No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vtrit_multiply::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vtrit_multiply___024root___eval_final(Vtrit_multiply___024root* vlSelf);

VL_ATTR_COLD void Vtrit_multiply::final() {
    Vtrit_multiply___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtrit_multiply::hierName() const { return vlSymsp->name(); }
const char* Vtrit_multiply::modelName() const { return "Vtrit_multiply"; }
unsigned Vtrit_multiply::threads() const { return 1; }
void Vtrit_multiply::prepareClone() const { contextp()->prepareClone(); }
void Vtrit_multiply::atClone() const {
    contextp()->threadPoolpOnClone();
}

//============================================================
// Trace configuration

VL_ATTR_COLD void Vtrit_multiply::trace(VerilatedVcdC* tfp, int levels, int options) {
    vl_fatal(__FILE__, __LINE__, __FILE__,"'Vtrit_multiply::trace()' called on model that was Verilated without --trace option");
}

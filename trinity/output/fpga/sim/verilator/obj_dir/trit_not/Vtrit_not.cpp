// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtrit_not__pch.h"

//============================================================
// Constructors

Vtrit_not::Vtrit_not(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtrit_not__Syms(contextp(), _vcname__, this)}
    , a{vlSymsp->TOP.a}
    , result{vlSymsp->TOP.result}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vtrit_not::Vtrit_not(const char* _vcname__)
    : Vtrit_not(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtrit_not::~Vtrit_not() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtrit_not___024root___eval_debug_assertions(Vtrit_not___024root* vlSelf);
#endif  // VL_DEBUG
void Vtrit_not___024root___eval_static(Vtrit_not___024root* vlSelf);
void Vtrit_not___024root___eval_initial(Vtrit_not___024root* vlSelf);
void Vtrit_not___024root___eval_settle(Vtrit_not___024root* vlSelf);
void Vtrit_not___024root___eval(Vtrit_not___024root* vlSelf);

void Vtrit_not::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtrit_not::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vtrit_not___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vtrit_not___024root___eval_static(&(vlSymsp->TOP));
        Vtrit_not___024root___eval_initial(&(vlSymsp->TOP));
        Vtrit_not___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vtrit_not___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vtrit_not::eventsPending() { return false; }

uint64_t Vtrit_not::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "%Error: No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vtrit_not::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vtrit_not___024root___eval_final(Vtrit_not___024root* vlSelf);

VL_ATTR_COLD void Vtrit_not::final() {
    Vtrit_not___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtrit_not::hierName() const { return vlSymsp->name(); }
const char* Vtrit_not::modelName() const { return "Vtrit_not"; }
unsigned Vtrit_not::threads() const { return 1; }
void Vtrit_not::prepareClone() const { contextp()->prepareClone(); }
void Vtrit_not::atClone() const {
    contextp()->threadPoolpOnClone();
}

//============================================================
// Trace configuration

VL_ATTR_COLD void Vtrit_not::trace(VerilatedVcdC* tfp, int levels, int options) {
    vl_fatal(__FILE__, __LINE__, __FILE__,"'Vtrit_not::trace()' called on model that was Verilated without --trace option");
}

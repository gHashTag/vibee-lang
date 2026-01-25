// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VTRIT_HALF_ADDER__SYMS_H_
#define VERILATED_VTRIT_HALF_ADDER__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vtrit_half_adder.h"

// INCLUDE MODULE CLASSES
#include "Vtrit_half_adder___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES)Vtrit_half_adder__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vtrit_half_adder* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vtrit_half_adder___024root     TOP;

    // CONSTRUCTORS
    Vtrit_half_adder__Syms(VerilatedContext* contextp, const char* namep, Vtrit_half_adder* modelp);
    ~Vtrit_half_adder__Syms();

    // METHODS
    const char* name() { return TOP.name(); }
};

#endif  // guard

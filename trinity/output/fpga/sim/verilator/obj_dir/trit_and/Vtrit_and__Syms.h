// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VTRIT_AND__SYMS_H_
#define VERILATED_VTRIT_AND__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vtrit_and.h"

// INCLUDE MODULE CLASSES
#include "Vtrit_and___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES)Vtrit_and__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vtrit_and* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vtrit_and___024root            TOP;

    // CONSTRUCTORS
    Vtrit_and__Syms(VerilatedContext* contextp, const char* namep, Vtrit_and* modelp);
    ~Vtrit_and__Syms();

    // METHODS
    const char* name() { return TOP.name(); }
};

#endif  // guard

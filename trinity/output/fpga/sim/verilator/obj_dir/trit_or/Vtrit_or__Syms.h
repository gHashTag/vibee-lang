// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VTRIT_OR__SYMS_H_
#define VERILATED_VTRIT_OR__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vtrit_or.h"

// INCLUDE MODULE CLASSES
#include "Vtrit_or___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES)Vtrit_or__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vtrit_or* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vtrit_or___024root             TOP;

    // CONSTRUCTORS
    Vtrit_or__Syms(VerilatedContext* contextp, const char* namep, Vtrit_or* modelp);
    ~Vtrit_or__Syms();

    // METHODS
    const char* name() { return TOP.name(); }
};

#endif  // guard

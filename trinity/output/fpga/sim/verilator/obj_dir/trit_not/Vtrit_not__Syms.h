// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VTRIT_NOT__SYMS_H_
#define VERILATED_VTRIT_NOT__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vtrit_not.h"

// INCLUDE MODULE CLASSES
#include "Vtrit_not___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES)Vtrit_not__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vtrit_not* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vtrit_not___024root            TOP;

    // CONSTRUCTORS
    Vtrit_not__Syms(VerilatedContext* contextp, const char* namep, Vtrit_not* modelp);
    ~Vtrit_not__Syms();

    // METHODS
    const char* name() { return TOP.name(); }
};

#endif  // guard

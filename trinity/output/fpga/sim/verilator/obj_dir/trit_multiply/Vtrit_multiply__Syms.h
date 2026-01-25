// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VTRIT_MULTIPLY__SYMS_H_
#define VERILATED_VTRIT_MULTIPLY__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vtrit_multiply.h"

// INCLUDE MODULE CLASSES
#include "Vtrit_multiply___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES)Vtrit_multiply__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vtrit_multiply* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vtrit_multiply___024root       TOP;

    // CONSTRUCTORS
    Vtrit_multiply__Syms(VerilatedContext* contextp, const char* namep, Vtrit_multiply* modelp);
    ~Vtrit_multiply__Syms();

    // METHODS
    const char* name() { return TOP.name(); }
};

#endif  // guard

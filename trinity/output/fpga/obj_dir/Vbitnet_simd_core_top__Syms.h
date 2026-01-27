// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VBITNET_SIMD_CORE_TOP__SYMS_H_
#define VERILATED_VBITNET_SIMD_CORE_TOP__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vbitnet_simd_core_top.h"

// INCLUDE MODULE CLASSES
#include "Vbitnet_simd_core_top___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES) Vbitnet_simd_core_top__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vbitnet_simd_core_top* const __Vm_modelp;
    bool __Vm_activity = false;  ///< Used by trace routines to determine change occurred
    uint32_t __Vm_baseCode = 0;  ///< Used by trace routines when tracing multiple models
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vbitnet_simd_core_top___024root TOP;

    // CONSTRUCTORS
    Vbitnet_simd_core_top__Syms(VerilatedContext* contextp, const char* namep, Vbitnet_simd_core_top* modelp);
    ~Vbitnet_simd_core_top__Syms();

    // METHODS
    const char* name() const { return TOP.vlNamep; }
};

#endif  // guard

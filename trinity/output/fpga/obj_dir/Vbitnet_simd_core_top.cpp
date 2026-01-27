// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vbitnet_simd_core_top__pch.h"
#include "verilated_vcd_c.h"

//============================================================
// Constructors

Vbitnet_simd_core_top::Vbitnet_simd_core_top(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vbitnet_simd_core_top__Syms(contextp(), _vcname__, this)}
    , clk{vlSymsp->TOP.clk}
    , rst_n{vlSymsp->TOP.rst_n}
    , valid_in{vlSymsp->TOP.valid_in}
    , valid_out{vlSymsp->TOP.valid_out}
    , ready{vlSymsp->TOP.ready}
    , data_in{vlSymsp->TOP.data_in}
    , data_out{vlSymsp->TOP.data_out}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
    contextp()->traceBaseModelCbAdd(
        [this](VerilatedTraceBaseC* tfp, int levels, int options) { traceBaseModel(tfp, levels, options); });
}

Vbitnet_simd_core_top::Vbitnet_simd_core_top(const char* _vcname__)
    : Vbitnet_simd_core_top(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vbitnet_simd_core_top::~Vbitnet_simd_core_top() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vbitnet_simd_core_top___024root___eval_debug_assertions(Vbitnet_simd_core_top___024root* vlSelf);
#endif  // VL_DEBUG
void Vbitnet_simd_core_top___024root___eval_static(Vbitnet_simd_core_top___024root* vlSelf);
void Vbitnet_simd_core_top___024root___eval_initial(Vbitnet_simd_core_top___024root* vlSelf);
void Vbitnet_simd_core_top___024root___eval_settle(Vbitnet_simd_core_top___024root* vlSelf);
void Vbitnet_simd_core_top___024root___eval(Vbitnet_simd_core_top___024root* vlSelf);

void Vbitnet_simd_core_top::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vbitnet_simd_core_top::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vbitnet_simd_core_top___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_activity = true;
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vbitnet_simd_core_top___024root___eval_static(&(vlSymsp->TOP));
        Vbitnet_simd_core_top___024root___eval_initial(&(vlSymsp->TOP));
        Vbitnet_simd_core_top___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vbitnet_simd_core_top___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vbitnet_simd_core_top::eventsPending() { return false; }

uint64_t Vbitnet_simd_core_top::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vbitnet_simd_core_top::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vbitnet_simd_core_top___024root___eval_final(Vbitnet_simd_core_top___024root* vlSelf);

VL_ATTR_COLD void Vbitnet_simd_core_top::final() {
    Vbitnet_simd_core_top___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vbitnet_simd_core_top::hierName() const { return vlSymsp->name(); }
const char* Vbitnet_simd_core_top::modelName() const { return "Vbitnet_simd_core_top"; }
unsigned Vbitnet_simd_core_top::threads() const { return 1; }
void Vbitnet_simd_core_top::prepareClone() const { contextp()->prepareClone(); }
void Vbitnet_simd_core_top::atClone() const {
    contextp()->threadPoolpOnClone();
}
std::unique_ptr<VerilatedTraceConfig> Vbitnet_simd_core_top::traceConfig() const {
    return std::unique_ptr<VerilatedTraceConfig>{new VerilatedTraceConfig{false, false, false}};
};

//============================================================
// Trace configuration

void Vbitnet_simd_core_top___024root__trace_decl_types(VerilatedVcd* tracep);

void Vbitnet_simd_core_top___024root__trace_init_top(Vbitnet_simd_core_top___024root* vlSelf, VerilatedVcd* tracep);

VL_ATTR_COLD static void trace_init(void* voidSelf, VerilatedVcd* tracep, uint32_t code) {
    // Callback from tracep->open()
    Vbitnet_simd_core_top___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vbitnet_simd_core_top___024root*>(voidSelf);
    Vbitnet_simd_core_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (!vlSymsp->_vm_contextp__->calcUnusedSigs()) {
        VL_FATAL_MT(__FILE__, __LINE__, __FILE__,
            "Turning on wave traces requires Verilated::traceEverOn(true) call before time 0.");
    }
    vlSymsp->__Vm_baseCode = code;
    tracep->pushPrefix(vlSymsp->name(), VerilatedTracePrefixType::SCOPE_MODULE);
    Vbitnet_simd_core_top___024root__trace_decl_types(tracep);
    Vbitnet_simd_core_top___024root__trace_init_top(vlSelf, tracep);
    tracep->popPrefix();
}

VL_ATTR_COLD void Vbitnet_simd_core_top___024root__trace_register(Vbitnet_simd_core_top___024root* vlSelf, VerilatedVcd* tracep);

VL_ATTR_COLD void Vbitnet_simd_core_top::traceBaseModel(VerilatedTraceBaseC* tfp, int levels, int options) {
    (void)levels; (void)options;
    VerilatedVcdC* const stfp = dynamic_cast<VerilatedVcdC*>(tfp);
    if (VL_UNLIKELY(!stfp)) {
        vl_fatal(__FILE__, __LINE__, __FILE__,"'Vbitnet_simd_core_top::trace()' called on non-VerilatedVcdC object;"
            " use --trace-fst with VerilatedFst object, and --trace-vcd with VerilatedVcd object");
    }
    stfp->spTrace()->addModel(this);
    stfp->spTrace()->addInitCb(&trace_init, &(vlSymsp->TOP));
    Vbitnet_simd_core_top___024root__trace_register(&(vlSymsp->TOP), stfp->spTrace());
}

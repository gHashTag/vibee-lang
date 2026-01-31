// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vhello_fpga_led_top__pch.h"
#include "verilated_vcd_c.h"

//============================================================
// Constructors

Vhello_fpga_led_top::Vhello_fpga_led_top(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vhello_fpga_led_top__Syms(contextp(), _vcname__, this)}
    , clk{vlSymsp->TOP.clk}
    , rst_n{vlSymsp->TOP.rst_n}
    , led{vlSymsp->TOP.led}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vhello_fpga_led_top::Vhello_fpga_led_top(const char* _vcname__)
    : Vhello_fpga_led_top(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vhello_fpga_led_top::~Vhello_fpga_led_top() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vhello_fpga_led_top___024root___eval_debug_assertions(Vhello_fpga_led_top___024root* vlSelf);
#endif  // VL_DEBUG
void Vhello_fpga_led_top___024root___eval_static(Vhello_fpga_led_top___024root* vlSelf);
void Vhello_fpga_led_top___024root___eval_initial(Vhello_fpga_led_top___024root* vlSelf);
void Vhello_fpga_led_top___024root___eval_settle(Vhello_fpga_led_top___024root* vlSelf);
void Vhello_fpga_led_top___024root___eval(Vhello_fpga_led_top___024root* vlSelf);

void Vhello_fpga_led_top::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vhello_fpga_led_top::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vhello_fpga_led_top___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_activity = true;
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vhello_fpga_led_top___024root___eval_static(&(vlSymsp->TOP));
        Vhello_fpga_led_top___024root___eval_initial(&(vlSymsp->TOP));
        Vhello_fpga_led_top___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vhello_fpga_led_top___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vhello_fpga_led_top::eventsPending() { return false; }

uint64_t Vhello_fpga_led_top::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "%Error: No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vhello_fpga_led_top::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vhello_fpga_led_top___024root___eval_final(Vhello_fpga_led_top___024root* vlSelf);

VL_ATTR_COLD void Vhello_fpga_led_top::final() {
    Vhello_fpga_led_top___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vhello_fpga_led_top::hierName() const { return vlSymsp->name(); }
const char* Vhello_fpga_led_top::modelName() const { return "Vhello_fpga_led_top"; }
unsigned Vhello_fpga_led_top::threads() const { return 1; }
void Vhello_fpga_led_top::prepareClone() const { contextp()->prepareClone(); }
void Vhello_fpga_led_top::atClone() const {
    contextp()->threadPoolpOnClone();
}
std::unique_ptr<VerilatedTraceConfig> Vhello_fpga_led_top::traceConfig() const {
    return std::unique_ptr<VerilatedTraceConfig>{new VerilatedTraceConfig{false, false, false}};
};

//============================================================
// Trace configuration

void Vhello_fpga_led_top___024root__trace_decl_types(VerilatedVcd* tracep);

void Vhello_fpga_led_top___024root__trace_init_top(Vhello_fpga_led_top___024root* vlSelf, VerilatedVcd* tracep);

VL_ATTR_COLD static void trace_init(void* voidSelf, VerilatedVcd* tracep, uint32_t code) {
    // Callback from tracep->open()
    Vhello_fpga_led_top___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vhello_fpga_led_top___024root*>(voidSelf);
    Vhello_fpga_led_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (!vlSymsp->_vm_contextp__->calcUnusedSigs()) {
        VL_FATAL_MT(__FILE__, __LINE__, __FILE__,
            "Turning on wave traces requires Verilated::traceEverOn(true) call before time 0.");
    }
    vlSymsp->__Vm_baseCode = code;
    tracep->pushPrefix(std::string{vlSymsp->name()}, VerilatedTracePrefixType::SCOPE_MODULE);
    Vhello_fpga_led_top___024root__trace_decl_types(tracep);
    Vhello_fpga_led_top___024root__trace_init_top(vlSelf, tracep);
    tracep->popPrefix();
}

VL_ATTR_COLD void Vhello_fpga_led_top___024root__trace_register(Vhello_fpga_led_top___024root* vlSelf, VerilatedVcd* tracep);

VL_ATTR_COLD void Vhello_fpga_led_top::trace(VerilatedVcdC* tfp, int levels, int options) {
    if (tfp->isOpen()) {
        vl_fatal(__FILE__, __LINE__, __FILE__,"'Vhello_fpga_led_top::trace()' shall not be called after 'VerilatedVcdC::open()'.");
    }
    if (false && levels && options) {}  // Prevent unused
    tfp->spTrace()->addModel(this);
    tfp->spTrace()->addInitCb(&trace_init, &(vlSymsp->TOP));
    Vhello_fpga_led_top___024root__trace_register(&(vlSymsp->TOP), tfp->spTrace());
}

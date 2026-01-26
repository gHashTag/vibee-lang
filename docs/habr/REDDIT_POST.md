# Reddit Post Draft: VIBEE FPGA Compiler

**Subreddits:** r/FPGA, r/OpenSource, r/Programming, r/Hardware

---

**Title:** Sick of $50k HLS tools? Meet VIBEE: The Open Source compiler for FPGA that supports Python, Rust, Go and 39+ more languages.

**Body:**

Hi everyone,

I’m excited to share **VIBEE**, an open-source project we’ve been working on to break down the barriers in FPGA development.

Traditional HLS tools like Xilinx Vitis or Intel HLS are great, but they come with a heavy price tag ($3k - $50k/year) and strict vendor lock-in. Plus, they mostly limit you to C/C++.

**VIBEE changes that.** It’s a "specification-first" compiler that turns high-level logic into synthesizable Verilog for **42 different programming languages.**

### 🚀 Key Features:
- **Free & Open Source:** $0 vs. tens of thousands.
- **Multi-Language Support:** Write in Python, Rust, Go, TypeScript, Zig, Swift, and dozens more.
- **No Vendor Lock-in:** Native support for AMD (Xilinx), Intel (Altera), and Lattice primitives via unified wrappers.
- **Built-in HLS Features:**
    - **Cycle-Accurate Reporting:** Automated latency estimation in the generated Verilog headers.
    - **Intention-based Pipelining:** Just set your `target_frequency` and `pipeline: auto`, and VIBEE handles the register balancing.
- **Fast Development:** 10x-100x faster than writing RTL by hand.

### 🐍 Real-world Example (Python to Verilog):
You can take a standard Python function and generate synthesizable Verilog with FSMs and testbenches in under 5 minutes using the `py2vibee` tool.

### 🧪 Check it out (60-second trial):
```bash
git clone https://github.com/gHashTag/vibee-lang
cd vibee-lang
./bin/vibee gen specs/tri/bitnet_top.vibee
# Check the output: trinity/output/fpga/bitnet_top.v
```

We’re building this for the next generation of "vibe coders" who want to build hardware as fast as they build software.

**Read the full story here:** 
[English Article on GitHub](https://github.com/gHashTag/vibee-lang/blob/main/docs/habr/HABR_ARTICLE_FPGA_COMPILER_EN.md)

**Repository:** 
[https://github.com/gHashTag/vibee-lang](https://github.com/gHashTag/vibee-lang)

Would love to hear your thoughts, feedback, or any languages you’d like to see added next!

---

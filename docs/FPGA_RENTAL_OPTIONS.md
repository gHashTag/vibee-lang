# FPGA Rental Options for BitNet Testing

## Cloud FPGA Services

### 1. AWS EC2 F2 Instances (Recommended for Production)

| Instance | FPGAs | vCPU | FPGA Memory | Price/hour |
|----------|-------|------|-------------|------------|
| f2.6xlarge | 1 | 24 | 16 GB HBM + 64 GB DDR4 | ~$3.50 |
| f2.12xlarge | 2 | 48 | 32 GB HBM + 128 GB DDR4 | ~$7.00 |
| f2.48xlarge | 8 | 192 | 128 GB HBM + 512 GB DDR4 | ~$28.00 |

**Pros:**
- AMD Virtex UltraScale+ HBM FPGAs
- Free Vivado license included
- AWS FPGA Developer AMI
- GitHub examples: github.com/aws/aws-fpga

**Cons:**
- Expensive for learning/prototyping
- Requires AWS account setup
- Overkill for simple BitNet MAC testing

**Best for:** Production deployment, large models

---

### 2. Nimbix Cloud (Good for Development)

**URL:** nimbix.net/fpga-compute

**Features:**
- FPGA Accelerated SaaS
- In-browser tools
- Batch processing support

**Pricing:** Contact for quote (typically $2-5/hour)

**Best for:** Development and testing

---

### 3. Alibaba Cloud FPGA (Budget Option)

**Features:**
- Xilinx FPGAs available
- Lower prices than AWS
- Good for Asia-based users

**Pricing:** ~$1-3/hour depending on instance

---

## Free/Low-Cost Alternatives

### 4. EDA Playground (FREE - Already Tested!)

**URL:** edaplayground.com

**Features:**
- Icarus Verilog simulation
- Verilator support
- No signup required
- Instant results

**Limitations:**
- Simulation only (no real FPGA)
- Limited compute time
- No synthesis

**Status:** ✅ Already used for BitNet MAC testing

---

### 5. Intel DevCloud (FREE)

**URL:** devcloud.intel.com

**Features:**
- Free access to Intel FPGAs
- Quartus Prime included
- 120 hours/month free

**Limitations:**
- Intel/Altera FPGAs only (not Xilinx)
- Queue times can be long
- Requires registration

**Best for:** Learning Intel FPGA flow

---

### 6. Xilinx Alveo Trial (FREE 30 days)

**URL:** xilinx.com/developer/alveo-trial

**Features:**
- Real Alveo FPGA access
- Vitis development environment
- 30-day free trial

**Best for:** Testing Xilinx-specific features

---

## Hardware Purchase Options (One-time Cost)

### 7. Digilent Arty A7-35T ($150)

**Specs:**
- Xilinx Artix-7 XC7A35T
- 33,280 logic cells
- 1.8 Mb BRAM
- 90 DSP slices

**Pros:**
- Own it forever
- No recurring costs
- Perfect for BitNet MAC testing
- Same chip as Ternary-NanoCore project

**Cons:**
- Upfront cost
- Need to install Vivado locally

**Status:** Issue #22 created for purchase

---

### 8. Sipeed Tang Nano 9K ($15-20)

**Specs:**
- Gowin GW1NR-9 FPGA
- 8,640 LUTs
- Chinese FPGA (not Xilinx)

**Pros:**
- Very cheap
- Good for learning
- Active community

**Cons:**
- Different toolchain (Gowin IDE)
- Less resources than Artix-7
- May need to port Verilog

---

### 9. DE10-Nano ($150-300)

**Specs:**
- Intel Cyclone V SoC
- ARM Cortex-A9 + FPGA
- 110K logic elements

**Pros:**
- ARM + FPGA combo
- Good for embedded AI
- Terasic support

**Cons:**
- Intel/Altera toolchain
- Different from Xilinx flow

---

## Recommendation for BitNet Testing

### Immediate (Free):
1. **EDA Playground** - Already working! ✅
2. **Intel DevCloud** - Free, real FPGA

### Short-term ($150):
3. **Arty A7-35T** - Best value, own forever

### Production ($$$):
4. **AWS F2** - When ready for real deployment

---

## Quick Start Commands

### EDA Playground (Free, Instant):
```
1. Go to edaplayground.com
2. Paste bitnet_mac_simple_tb.v
3. Select "Icarus Verilog 12.0"
4. Click "Run"
```

### AWS F2 (Paid):
```bash
# Launch F2 instance with FPGA Developer AMI
aws ec2 run-instances \
  --image-id ami-0123456789 \
  --instance-type f2.6xlarge \
  --key-name my-key

# Clone AWS FPGA repo
git clone https://github.com/aws/aws-fpga
cd aws-fpga
source sdk_setup.sh
```

### Intel DevCloud (Free):
```bash
# Register at devcloud.intel.com
# SSH to devcloud
ssh devcloud

# Load Quartus
module load quartus

# Compile design
quartus_sh --flow compile bitnet_mac
```

---

## Cost Comparison Summary

| Option | Cost | Real FPGA? | Best For |
|--------|------|------------|----------|
| EDA Playground | FREE | No (sim) | Quick testing |
| Intel DevCloud | FREE | Yes | Learning |
| Alveo Trial | FREE (30d) | Yes | Xilinx eval |
| Tang Nano 9K | $15 | Yes | Budget learning |
| Arty A7-35T | $150 | Yes | **Recommended** |
| AWS F2 | $3.50/hr | Yes | Production |

---

**Recommendation:** Start with EDA Playground (free), then buy Arty A7-35T ($150) for physical proof.

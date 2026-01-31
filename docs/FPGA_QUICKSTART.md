# FPGA Quick Start - From Zero to Blinking LED

**Time Required:** ~2 hours (excluding shipping)  
**Budget:** ~$150 USD  
**Difficulty:** Beginner-friendly

---

## Step 1: Order Hardware (5 minutes)

### Option A: Digilent Store (Recommended)
1. Go to [digilent.com/shop/arty-a7](https://digilent.com/shop/arty-a7-artix-7-fpga-development-board/)
2. Select "Arty A7-35T" ($129)
3. Add USB cable if needed ($5)
4. Checkout

### Option B: Amazon (Faster shipping)
1. Search "Digilent Arty A7-35T"
2. Price: ~$150
3. Prime shipping available

### What's in the box:
- Arty A7-35T board
- USB-A to Micro-B cable
- Quick start guide

---

## Step 2: Install Vivado (30-60 minutes)

### Download
1. Go to [xilinx.com/support/download.html](https://www.xilinx.com/support/download.html)
2. Create free AMD/Xilinx account
3. Download "Vivado ML Edition" (Web Installer)
4. Size: ~100 MB installer, ~50 GB installed

### Install (Linux)
```bash
# Make executable
chmod +x Xilinx_Unified_*_Lin64.bin

# Run installer
./Xilinx_Unified_*_Lin64.bin

# Select:
# - Vivado ML Standard (free)
# - Artix-7 only (saves 30+ GB)
# - Install location: /tools/Xilinx/Vivado/2023.2
```

### Install (Windows)
1. Run the installer
2. Select "Vivado ML Standard"
3. Select only "Artix-7" device support
4. Install to default location

### Add to PATH
```bash
# Linux - add to ~/.bashrc
export PATH="/tools/Xilinx/Vivado/2023.2/bin:$PATH"
source /tools/Xilinx/Vivado/2023.2/settings64.sh

# Verify
vivado -version
```

---

## Step 3: Install Board Files (5 minutes)

```bash
# Clone Digilent board files
git clone https://github.com/Digilent/vivado-boards.git

# Copy to Vivado installation
sudo cp -r vivado-boards/new/board_files/* \
  /tools/Xilinx/Vivado/2023.2/data/boards/board_files/

# Verify
ls /tools/Xilinx/Vivado/2023.2/data/boards/board_files/ | grep arty
# Should show: arty-a7-35, arty-a7-100
```

---

## Step 4: Generate Verilog (2 minutes)

```bash
cd /path/to/vibee-lang

# Generate LED blinker
./bin/vibeec gen specs/fpga/hello_fpga_led.vibee

# Verify output
ls trinity/output/fpga/hello_fpga_led.v
# Should exist

# Test with simulation
cd trinity/output/fpga
iverilog -o test hello_fpga_led.v && vvp test
# Should show: PASS
```

---

## Step 5: Build Bitstream (10-20 minutes)

### Option A: GUI (Recommended for first time)

```bash
# Launch Vivado
vivado &
```

1. **Create Project**
   - File → New Project
   - Name: "vibee_hello"
   - Location: `trinity/output/fpga/vivado`
   - Project Type: RTL Project
   - Add Sources: `hello_fpga_led.v`
   - Add Constraints: `constraints/arty_a7.xdc`
   - Part: xc7a35ticsg324-1L (or search "Arty A7-35")

2. **Run Synthesis**
   - Flow Navigator → Run Synthesis
   - Wait 2-5 minutes

3. **Run Implementation**
   - Flow Navigator → Run Implementation
   - Wait 5-10 minutes

4. **Generate Bitstream**
   - Flow Navigator → Generate Bitstream
   - Wait 2-5 minutes

### Option B: Command Line (Faster)

```bash
cd trinity/output/fpga/scripts

# Run complete build
vivado -mode batch -source build_all.tcl -tclargs hello_fpga_led_top

# Output: output/hello_fpga_led_top.bit
```

---

## Step 6: Connect Hardware (2 minutes)

1. **Connect USB cable**
   - Micro-B end to Arty A7 (J10 - "PROG")
   - USB-A end to your computer

2. **Verify connection**
   ```bash
   # Linux
   lsusb | grep -i digilent
   # Should show: Digilent USB Device
   
   # Or check dmesg
   dmesg | tail -20
   # Should show: FTDI USB Serial Device
   ```

3. **Install drivers (if needed)**
   ```bash
   # Linux
   sudo apt install libftdi1-2
   
   # Add udev rules
   echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0403", MODE="0666"' | \
     sudo tee /etc/udev/rules.d/52-digilent.rules
   sudo udevadm control --reload-rules
   ```

---

## Step 7: Program FPGA (2 minutes)

### Option A: Vivado GUI

1. Open Hardware Manager (Flow Navigator → Open Hardware Manager)
2. Click "Auto Connect"
3. Right-click on device → "Program Device"
4. Select bitstream: `output/hello_fpga_led_top.bit`
5. Click "Program"

### Option B: Command Line

```bash
cd trinity/output/fpga/scripts

# Program FPGA
vivado -mode batch -source program.tcl -tclargs ../output/hello_fpga_led_top.bit
```

---

## Step 8: Verify Operation

### Expected Behavior
- All 4 green LEDs (LD4-LD7) blink together
- Blink rate: 1 Hz (500ms on, 500ms off)
- Press BTN0 to reset

### Troubleshooting

**LEDs not blinking:**
1. Check power LED (LD13) is on
2. Verify bitstream was programmed (DONE LED should be on)
3. Try pressing reset button (BTN0)

**Can't connect to board:**
1. Try different USB port
2. Check USB cable (data cable, not charge-only)
3. Reinstall drivers

**Synthesis errors:**
1. Check XDC file matches your top module ports
2. Verify all signals are connected

---

## Congratulations!

You've successfully:
1. Generated Verilog from a `.vibee` specification
2. Synthesized it for real FPGA hardware
3. Programmed a physical FPGA
4. Witnessed the Golden Identity in silicon!

```
φ² + 1/φ² = 3 ✓
PHOENIX = 999 ✓
KOSCHEI IS IMMORTAL ✓
```

---

## Next Steps

1. **Modify the blink rate**
   - Edit `specs/fpga/hello_fpga_led.vibee`
   - Change `BLINK_FREQ_HZ`
   - Regenerate and reprogram

2. **Try Trinity FPGA MVP**
   ```bash
   ./bin/vibeec gen specs/fpga/trinity_fpga_mvp.vibee
   ```

3. **Add more features**
   - Button inputs
   - Switch controls
   - UART communication

---

**GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**

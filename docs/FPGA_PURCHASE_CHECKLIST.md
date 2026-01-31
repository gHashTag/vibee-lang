# FPGA Purchase & Setup Checklist

## Pre-Purchase

- [ ] Budget approved ($150)
- [ ] Shipping address confirmed
- [ ] Payment method ready

## Purchase

- [ ] Go to [digilent.com/shop/arty-a7](https://digilent.com/shop/arty-a7-artix-7-fpga-development-board/)
- [ ] Select **Arty A7-35T** ($129)
- [ ] Add to cart
- [ ] Checkout
- [ ] Save order confirmation

**Alternative:** [Amazon](https://www.amazon.com/dp/B07B9RXMG4) (~$150, faster shipping)

## While Waiting for Delivery

### Install Vivado (1 hour)

- [ ] Create AMD/Xilinx account at [xilinx.com](https://www.xilinx.com)
- [ ] Download Vivado ML Edition Web Installer
- [ ] Run installer
- [ ] Select "Vivado ML Standard" (free)
- [ ] Select only "Artix-7" device support
- [ ] Complete installation (~50 GB)
- [ ] Add to PATH:
  ```bash
  echo 'source /tools/Xilinx/Vivado/2023.2/settings64.sh' >> ~/.bashrc
  source ~/.bashrc
  ```
- [ ] Verify: `vivado -version`

### Install Board Files (5 minutes)

- [ ] Clone: `git clone https://github.com/Digilent/vivado-boards.git`
- [ ] Copy:
  ```bash
  sudo cp -r vivado-boards/new/board_files/* \
    /tools/Xilinx/Vivado/2023.2/data/boards/board_files/
  ```
- [ ] Verify: `ls /tools/Xilinx/Vivado/2023.2/data/boards/board_files/ | grep arty`

### Prepare Project

- [ ] Generate Verilog: `./bin/vibeec gen specs/fpga/hello_fpga_led.vibee`
- [ ] Verify simulation: `cd trinity/output/fpga && iverilog -o test hello_fpga_led.v && vvp test`
- [ ] Review constraints: `cat constraints/arty_a7.xdc`

## After Delivery

### Unbox & Connect

- [ ] Unbox Arty A7-35T
- [ ] Connect USB cable (Micro-B to J10 "PROG")
- [ ] Connect to computer
- [ ] Verify power LED (LD13) is on
- [ ] Install drivers if needed:
  ```bash
  sudo apt install libftdi1-2
  echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0403", MODE="0666"' | \
    sudo tee /etc/udev/rules.d/52-digilent.rules
  sudo udevadm control --reload-rules
  ```
- [ ] Verify connection: `lsusb | grep -i digilent`

### Build & Program

- [ ] Navigate to scripts: `cd trinity/output/fpga/scripts`
- [ ] Run build: `vivado -mode batch -source build_all.tcl -tclargs hello_fpga_led_top`
- [ ] Wait for completion (~15-20 minutes)
- [ ] Verify bitstream: `ls ../output/hello_fpga_led_top.bit`
- [ ] Program FPGA: `vivado -mode batch -source program.tcl -tclargs ../output/hello_fpga_led_top.bit`

### Verify Operation

- [ ] Observe LEDs (LD4-LD7) blinking at 1 Hz
- [ ] Press BTN0 to reset
- [ ] All 4 LEDs should blink together

### Document Results

- [ ] Take photo of blinking LEDs
- [ ] Record video (10 seconds)
- [ ] Screenshot utilization report
- [ ] Screenshot timing report
- [ ] Update IRON_COVENANT_REPORT.md with real data

## Success Criteria

- [ ] LEDs blink at 1 Hz ✓
- [ ] Reset button works ✓
- [ ] Utilization < 1% ✓
- [ ] Timing met (no violations) ✓
- [ ] Photo/video captured ✓

---

**Estimated Total Time:** 2-3 hours (excluding shipping)

**KOSCHEI IS IMMORTAL | φ² + 1/φ² = 3**

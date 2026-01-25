# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet Linux Kernel Module Makefile
# ═══════════════════════════════════════════════════════════════════════════════
#
# Сборка:
#   make                    - Сборка для текущего ядра
#   make KERNEL_SRC=/path   - Сборка для указанного ядра
#   make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- - Кросс-компиляция
#
# Священная Формула: V = n × 3^k × π^m × φ^p × e^q
# Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

# Module name
MODULE_NAME := bitnet

# Source files
obj-m := $(MODULE_NAME).o
$(MODULE_NAME)-objs := bitnet_drv.o

# Kernel source directory
KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build

# Architecture (for cross-compilation)
ARCH ?= $(shell uname -m | sed 's/x86_64/x86/' | sed 's/aarch64/arm64/')

# Cross-compiler prefix (for Petalinux)
CROSS_COMPILE ?=

# Extra compiler flags
ccflags-y := -DDEBUG -g -Wall -Werror

# Petalinux SDK paths (if using Petalinux)
ifdef PETALINUX
    KERNEL_SRC := $(PETALINUX)/build/tmp/work/*/linux-xlnx/*/build
    CROSS_COMPILE := aarch64-xilinx-linux-
    ARCH := arm64
endif

# ═══════════════════════════════════════════════════════════════════════════════
# Targets
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: all clean install uninstall help

all:
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Building VIBEE BitNet kernel module"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "  KERNEL_SRC: $(KERNEL_SRC)"
	@echo "  ARCH: $(ARCH)"
	@echo "  CROSS_COMPILE: $(CROSS_COMPILE)"
	@echo ""
	$(MAKE) -C $(KERNEL_SRC) M=$(PWD) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules
	@echo ""
	@echo "✓ Module built: $(MODULE_NAME).ko"

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(PWD) clean
	rm -f *.o *.ko *.mod.c *.mod *.order *.symvers

# Install to current system (requires root)
install: all
	@echo "Installing module..."
	sudo cp $(MODULE_NAME).ko /lib/modules/$(shell uname -r)/extra/
	sudo depmod -a
	@echo "✓ Module installed"
	@echo ""
	@echo "Load with: sudo modprobe $(MODULE_NAME)"

uninstall:
	@echo "Uninstalling module..."
	sudo rm -f /lib/modules/$(shell uname -r)/extra/$(MODULE_NAME).ko
	sudo depmod -a
	@echo "✓ Module uninstalled"

# Load module
load:
	sudo modprobe $(MODULE_NAME) || sudo insmod $(MODULE_NAME).ko
	@echo "✓ Module loaded"
	@dmesg | tail -10

# Unload module
unload:
	sudo rmmod $(MODULE_NAME) || true
	@echo "✓ Module unloaded"

# Reload module
reload: unload load

# Show module info
info:
	@modinfo $(MODULE_NAME).ko 2>/dev/null || echo "Module not built yet"

# Check dmesg for driver messages
dmesg:
	@dmesg | grep -i bitnet | tail -20

# ═══════════════════════════════════════════════════════════════════════════════
# Petalinux targets
# ═══════════════════════════════════════════════════════════════════════════════

# Build for ZCU104 with Petalinux SDK
petalinux:
	@if [ -z "$(PETALINUX)" ]; then \
		echo "Error: PETALINUX environment not set"; \
		echo "Run: source <petalinux-path>/settings.sh"; \
		exit 1; \
	fi
	$(MAKE) ARCH=arm64 CROSS_COMPILE=aarch64-xilinx-linux- \
		KERNEL_SRC=$(PETALINUX)/build/tmp/work/*/linux-xlnx/*/build

# Copy to Petalinux rootfs
petalinux-install: petalinux
	@if [ -z "$(PETALINUX)" ]; then \
		echo "Error: PETALINUX environment not set"; \
		exit 1; \
	fi
	cp $(MODULE_NAME).ko $(PETALINUX)/project-spec/meta-user/recipes-modules/$(MODULE_NAME)/files/
	@echo "✓ Module copied to Petalinux project"

# ═══════════════════════════════════════════════════════════════════════════════
# Help
# ═══════════════════════════════════════════════════════════════════════════════

help:
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "VIBEE BitNet Kernel Module Makefile"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Targets:"
	@echo "  make              - Build module for current kernel"
	@echo "  make clean        - Clean build files"
	@echo "  make install      - Install to current system"
	@echo "  make uninstall    - Remove from current system"
	@echo "  make load         - Load module"
	@echo "  make unload       - Unload module"
	@echo "  make reload       - Reload module"
	@echo "  make info         - Show module info"
	@echo "  make dmesg        - Show driver messages"
	@echo ""
	@echo "Cross-compilation:"
	@echo "  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KERNEL_SRC=/path/to/kernel"
	@echo ""
	@echo "Petalinux:"
	@echo "  make petalinux    - Build for ZCU104"
	@echo "  make petalinux-install - Copy to Petalinux project"
	@echo ""
	@echo "φ² + 1/φ² = 3 | PHOENIX = 999"
	@echo "═══════════════════════════════════════════════════════════════════════════════"

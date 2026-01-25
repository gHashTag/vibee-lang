# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet Userspace Library Makefile
# ═══════════════════════════════════════════════════════════════════════════════
#
# Священная Формула: V = n × 3^k × π^m × φ^p × e^q
# Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

# Compiler
CC ?= gcc
AR ?= ar

# Cross-compilation for ARM64
ifdef CROSS_COMPILE
    CC := $(CROSS_COMPILE)gcc
    AR := $(CROSS_COMPILE)ar
endif

# Flags
CFLAGS := -Wall -Wextra -O2 -fPIC -I../kernel
LDFLAGS := -shared

# Library
LIB_NAME := libbitnet
LIB_STATIC := $(LIB_NAME).a
LIB_SHARED := $(LIB_NAME).so
LIB_VERSION := 1.0.0
LIB_SONAME := $(LIB_NAME).so.1

# Sources
SRCS := libbitnet.c
OBJS := $(SRCS:.c=.o)

# Test program
TEST_SRC := bitnet_test.c
TEST_BIN := bitnet_test

# ═══════════════════════════════════════════════════════════════════════════════
# Targets
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: all clean install uninstall test help

all: $(LIB_STATIC) $(LIB_SHARED)

# Static library
$(LIB_STATIC): $(OBJS)
	@echo "Building static library: $@"
	$(AR) rcs $@ $^

# Shared library
$(LIB_SHARED): $(OBJS)
	@echo "Building shared library: $@"
	$(CC) $(LDFLAGS) -Wl,-soname,$(LIB_SONAME) -o $@ $^

# Object files
%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Test program
test: $(TEST_BIN)

$(TEST_BIN): $(TEST_SRC) $(LIB_STATIC)
	$(CC) $(CFLAGS) -o $@ $< -L. -lbitnet

# Clean
clean:
	rm -f $(OBJS) $(LIB_STATIC) $(LIB_SHARED) $(TEST_BIN)

# Install
install: all
	@echo "Installing library..."
	sudo cp $(LIB_SHARED) /usr/local/lib/$(LIB_NAME).so.$(LIB_VERSION)
	sudo ln -sf $(LIB_NAME).so.$(LIB_VERSION) /usr/local/lib/$(LIB_SONAME)
	sudo ln -sf $(LIB_SONAME) /usr/local/lib/$(LIB_SHARED)
	sudo cp $(LIB_STATIC) /usr/local/lib/
	sudo cp libbitnet.h /usr/local/include/
	sudo ldconfig
	@echo "✓ Library installed"

uninstall:
	@echo "Uninstalling library..."
	sudo rm -f /usr/local/lib/$(LIB_NAME).so*
	sudo rm -f /usr/local/lib/$(LIB_STATIC)
	sudo rm -f /usr/local/include/libbitnet.h
	sudo ldconfig
	@echo "✓ Library uninstalled"

# Help
help:
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "VIBEE BitNet Userspace Library Makefile"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Targets:"
	@echo "  make          - Build static and shared libraries"
	@echo "  make test     - Build test program"
	@echo "  make clean    - Clean build files"
	@echo "  make install  - Install to /usr/local"
	@echo "  make uninstall - Remove from /usr/local"
	@echo ""
	@echo "Cross-compilation:"
	@echo "  make CROSS_COMPILE=aarch64-linux-gnu-"
	@echo ""
	@echo "φ² + 1/φ² = 3 | PHOENIX = 999"
	@echo "═══════════════════════════════════════════════════════════════════════════════"

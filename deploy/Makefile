# IGLA Production Makefile
# ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
# PHOENIX = 999 = 3³ × 37

.PHONY: all build test benchmark clean install release

VERSION := 3.0.0
PHOENIX := 999

# Directories
SRC_DIR := ../src/vibeec
BINDINGS_DIR := ../bindings
BUILD_DIR := ../build
DIST_DIR := ../dist

all: build

build:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "  Building IGLA v$(VERSION) - PHOENIX = $(PHOENIX)"
	@echo "═══════════════════════════════════════════════════════════════"
	cd $(SRC_DIR) && zig build -Doptimize=ReleaseFast
	@echo "✅ Compiler built"

build-python:
	@echo "Building Python bindings..."
	cd $(BINDINGS_DIR)/python && zig build-lib igla_lib.zig -dynamic -O ReleaseFast -femit-bin=libigla.so
	@echo "✅ Python bindings built"

build-wasm:
	@echo "Building WASM module..."
	cd $(BINDINGS_DIR)/wasm && zig build-exe igla.zig -target wasm32-freestanding -O ReleaseFast -fno-entry
	@echo "✅ WASM module built"

test:
	@echo "Running tests..."
	cd $(SRC_DIR) && zig test parser.zig
	cd $(SRC_DIR) && zig test codegen.zig
	cd $(SRC_DIR) && zig test pas.zig
	@echo "✅ All tests passed"

benchmark:
	@echo "Running benchmarks..."
	cd $(BINDINGS_DIR)/python && python3 igla.py
	@echo "✅ Benchmarks complete"

clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR)
	rm -f $(SRC_DIR)/zig-out
	rm -f $(BINDINGS_DIR)/python/*.so
	rm -f $(BINDINGS_DIR)/wasm/*.wasm
	@echo "✅ Cleaned"

install: build build-python build-wasm
	mkdir -p /usr/local/bin /usr/local/lib
	cp $(SRC_DIR)/zig-out/bin/vibeec /usr/local/bin/
	cp $(BINDINGS_DIR)/python/libigla.so /usr/local/lib/
	@echo "✅ Installed to /usr/local"

release: clean build build-python build-wasm
	mkdir -p $(DIST_DIR)
	cp $(SRC_DIR)/zig-out/bin/vibeec $(DIST_DIR)/
	cp $(BINDINGS_DIR)/python/libigla.so $(DIST_DIR)/
	cp $(BINDINGS_DIR)/python/igla.py $(DIST_DIR)/
	cp $(BINDINGS_DIR)/wasm/igla.wasm $(DIST_DIR)/
	tar -czvf igla-$(VERSION)-linux-x86_64.tar.gz -C $(DIST_DIR) .
	@echo "✅ Release package created: igla-$(VERSION)-linux-x86_64.tar.gz"

docker:
	docker build -t igla:$(VERSION) -f Dockerfile ..
	@echo "✅ Docker image built: igla:$(VERSION)"

docker-push:
	docker tag igla:$(VERSION) ghcr.io/ghashtag/igla:$(VERSION)
	docker push ghcr.io/ghashtag/igla:$(VERSION)
	@echo "✅ Pushed to ghcr.io"

help:
	@echo "IGLA Build System - PHOENIX = $(PHOENIX)"
	@echo ""
	@echo "Targets:"
	@echo "  build        - Build compiler"
	@echo "  build-python - Build Python bindings"
	@echo "  build-wasm   - Build WASM module"
	@echo "  test         - Run all tests"
	@echo "  benchmark    - Run benchmarks"
	@echo "  clean        - Clean build artifacts"
	@echo "  install      - Install to /usr/local"
	@echo "  release      - Create release package"
	@echo "  docker       - Build Docker image"
	@echo "  docker-push  - Push to GitHub Container Registry"

# ==============================================================================
# Makefile: Cache Simulation and Verification Harness
# Project: Design and Performance Analysis of a 2-Way Set-Associative Cache
#          with LRU Replacement Compared with a Direct-Mapped Cache
# ==============================================================================

IVERILOG = /opt/homebrew/bin/iverilog
VVP      = /opt/homebrew/bin/vvp

.PHONY: all direct sim_direct clean help

all: direct

direct:
	@mkdir -p build results waveforms
	@echo ">>> Compiling Direct-Mapped Cache Baseline (Verilog-2001)..."
	$(IVERILOG) -g2001 -Wall -o build/sim_direct.vvp rtl/cache_direct.v tb/tb_direct.v
	@echo ">>> Running Direct-Mapped Cache Simulation..."
	$(VVP) build/sim_direct.vvp | tee results/sim_direct.log

sim_direct: direct

clean:
	@rm -f build/*.vvp results/*.log waveforms/*.vcd
	@echo ">>> Cleaned build binaries, logs, and waveforms."

help:
	@echo "Available build targets:"
	@echo "  make direct      - Compile and run direct-mapped cache simulation"
	@echo "  make clean       - Remove generated simulation outputs"


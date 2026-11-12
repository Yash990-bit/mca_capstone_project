# ==============================================================================
# Makefile: Cache Simulation and Verification Harness
# Project: Design and Performance Analysis of a 2-Way Set-Associative Cache
#          with LRU Replacement Compared with a Direct-Mapped Cache
# ==============================================================================

IVERILOG ?= iverilog
VVP      ?= vvp

.PHONY: all direct sim_direct sim_2way sim_lru_fsm clean help

all: direct

direct:
	@mkdir -p build results waveforms
	@echo ">>> Compiling Direct-Mapped Cache Baseline (Verilog-2001)..."
	$(IVERILOG) -g2001 -Wall -o build/sim_direct.vvp rtl/cache_direct.v tb/tb_direct.v
	@echo ">>> Running Direct-Mapped Cache Simulation..."
	$(VVP) build/sim_direct.vvp | tee results/sim_direct.log

sim_direct: direct

sim_2way:
	@mkdir -p build results waveforms
	@echo ">>> Compiling 2-Way Set-Associative Cache (Verilog-2001)..."
	$(IVERILOG) -g2001 -Wall -o build/sim_2way_keshav.vvp rtl/cache_2way.v rtl/lru_controller.v tb/tb_cache_2way_keshav.v
	@echo ">>> Running 2-Way Set-Associative Cache Simulation..."
	$(VVP) build/sim_2way_keshav.vvp | tee results/sim_2way_keshav.log

sim_lru_fsm:
	@mkdir -p build results waveforms
	@echo ">>> Compiling LRU Controller & Cache FSM (Verilog-2001)..."
	$(IVERILOG) -g2001 -Wall -o build/sim_lru_fsm.vvp rtl/lru_controller.v rtl/cache_fsm.v tb/tb_lru_fsm.v
	@echo ">>> Running LRU & FSM Unit Simulation..."
	$(VVP) build/sim_lru_fsm.vvp | tee results/sim_lru_fsm.log

clean:
	@rm -f build/*.vvp results/*.log waveforms/*.vcd
	@echo ">>> Cleaned build binaries, logs, and waveforms."

help:
	@echo "Available build targets:"
	@echo "  make direct      - Compile and run direct-mapped cache simulation"
	@echo "  make sim_2way    - Compile and run Keshav's 2-way cache unit test"
	@echo "  make clean       - Remove generated simulation outputs"


#!/usr/bin/env bash
# =============================================================================
# sim/run_sim.sh  — Full simulation runner for MCA Capstone Cache Project
# Author : Kaavya (Verification Engineer)
# Usage  : bash sim/run_sim.sh
#          Run from the project root directory.
# =============================================================================

set -e   # exit on any error
PROJ_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJ_ROOT"

# ---- Colour helpers ----------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}[OK ]${NC} $*"; }
fail() { echo -e "${RED}[ERR]${NC} $*"; }
info() { echo -e "${YELLOW}[INF]${NC} $*"; }

# ---- Directories -------------------------------------------------------------
mkdir -p build waveforms results

# ---- Tool check --------------------------------------------------------------
info "Checking for Icarus Verilog..."
if ! command -v iverilog &> /dev/null; then
    fail "iverilog not found. Install with: brew install icarus-verilog"
    exit 1
fi
IVVER=$(iverilog -V 2>&1 | head -1)
info "Using: $IVVER"

# =============================================================================
# 1. Compile & simulate 2-way cache testbench
# =============================================================================
info "Compiling tb_2way ..."
iverilog -g2001 -Wall \
    -o build/sim_2way \
    rtl/lru_controller.v \
    rtl/cache_2way.v \
    tb/tb_2way.v 2>&1 | tee build/compile_2way.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    fail "Compilation of tb_2way FAILED — see build/compile_2way.log"
    exit 1
fi
pass "tb_2way compilation OK"

info "Running tb_2way simulation ..."
vvp build/sim_2way 2>&1 | tee results/sim_2way.log

if grep -q "\[FAIL\]" results/sim_2way.log; then
    fail "tb_2way: Some tests FAILED — review results/sim_2way.log"
else
    pass "tb_2way: All tests PASSED"
fi

# =============================================================================
# 2. Compile & simulate direct-mapped cache testbench
# =============================================================================
info "Compiling tb_direct ..."
iverilog -g2001 -Wall \
    -o build/sim_direct \
    rtl/cache_direct.v \
    tb/tb_direct.v 2>&1 | tee build/compile_direct.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    fail "Compilation of tb_direct FAILED — see build/compile_direct.log"
    exit 1
fi
pass "tb_direct compilation OK"

info "Running tb_direct simulation ..."
vvp build/sim_direct 2>&1 | tee results/sim_direct.log

if grep -q "\[FAIL\]" results/sim_direct.log; then
    fail "tb_direct: Some tests FAILED — review results/sim_direct.log"
else
    pass "tb_direct: All tests PASSED"
fi

# =============================================================================
# 3. Parse simulation logs → CSV files
# =============================================================================
info "Generating CSV results ..."
python3 sim/parse_results.py

pass "Results written to results/"
info "Waveform files: waveforms/wave_2way.vcd  waveforms/wave_direct.vcd"
info "Open with GTKWave: gtkwave waveforms/wave_2way.vcd"
echo ""
echo "===== Simulation Run Complete ====="


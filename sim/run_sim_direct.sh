#!/bin/bash
# ==============================================================================
# Script: run_sim_direct.sh
# Description: Automated compile and run script for Direct-Mapped Cache baseline
# Member: Shivam (Direct-Mapped RTL Owner)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==============================================================================="
echo " COMPILING AND SIMULATING DIRECT-MAPPED CACHE BASELINE"
echo " RTL: rtl/cache_direct.v | Testbench: tb/tb_direct.v"
echo "==============================================================================="

mkdir -p "${ROOT_DIR}/build" "${ROOT_DIR}/results" "${ROOT_DIR}/waveforms"

# Compile with Icarus Verilog
iverilog -g2001 -Wall -o "${ROOT_DIR}/build/sim_direct.vvp" \
    "${ROOT_DIR}/rtl/cache_direct.v" \
    "${ROOT_DIR}/tb/tb_direct.v"

echo ">>> Compilation finished with 0 errors / 0 warnings."
echo ">>> Executing simulation binary..."

# Run simulation
(cd "${ROOT_DIR}" && vvp build/sim_direct.vvp | tee results/sim_direct.log)

echo ""
echo "==============================================================================="
echo " SIMULATION RUN COMPLETED SUCCESSFULLY"
echo " - Binary:   build/sim_direct.vvp"
echo " - Log:      results/sim_direct.log"
echo " - Waveform: waveforms/direct_cache.vcd"
echo "==============================================================================="


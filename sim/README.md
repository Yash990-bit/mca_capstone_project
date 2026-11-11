# Simulation Environment & Scripts

This folder contains guidelines and scripts for compiling and running simulations using **Icarus Verilog (`iverilog`)** and inspecting waveforms via **GTKWave**.

---

## Tool Prerequisites
- **Icarus Verilog:** `iverilog` and `vvp`
- **Waveform Viewer:** `gtkwave`

---

## Planned Simulation Commands (For Verification Phase)

### 1. Direct-Mapped Cache Simulation
```bash
# Compile
iverilog -g2001 -o ../build/sim_direct.vvp ../rtl/cache_direct.v ../tb/tb_direct.v

# Execute
vvp ../build/sim_direct.vvp

# View Waveforms
gtkwave ../waveforms/direct_cache.vcd
```

### 2. 2-Way Set-Associative Cache Simulation
```bash
# Compile
iverilog -g2001 -o ../build/sim_2way.vvp ../rtl/cache_2way.v ../rtl/lru_controller.v ../rtl/cache_fsm.v ../tb/tb_2way.v

# Execute
vvp ../build/sim_2way.vvp

# View Waveforms
gtkwave ../waveforms/2way_cache.vcd
```

### 3. Top-Level Comparative Benchmark
```bash
# Compile
iverilog -g2001 -o ../build/sim_top.vvp ../rtl/*.v ../tb/tb_top.v

# Execute
vvp ../build/sim_top.vvp
```


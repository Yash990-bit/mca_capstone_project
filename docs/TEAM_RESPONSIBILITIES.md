# Team Member Responsibilities & Work Breakdown Structure

> **Project Title:** Design and Performance Analysis of a 2-Way Set-Associative Cache with LRU Replacement Compared with a Direct-Mapped Cache  
> **Status:** Initial Setup & Architectural Baseline Defined

---

## 1. Team Roster & Ownership Overview

| Member | Assigned Role | Primary Focus Area |
|:---|:---|:---|
| **Yash** | Lead Architect & Repository Engineer | Project Architecture, Git Hygiene, System Integration & Module Interfaces |
| **Keshav** | RTL Engineer (2-Way Cache) | 2-Way Set-Associative Cache Datapath & Dual Comparator Logic |
| **Shitanshu** | RTL Engineer (Control & LRU) | LRU Replacement Unit & Cache Controller FSM |
| **Shivam** | RTL Engineer (Direct-Mapped) | Direct-Mapped Cache Datapath & Baseline Storage Array |
| **Kaavya** | Verification & Simulation Engineer | Verification Suites, Testbenches, Waveform Analysis & Performance Metrics |

---

## 2. Detailed Member Responsibilities & Deliverables

### 2.1 Yash — Project Architecture and Repository Setup
- **Scope & Objectives:**
  - Establish and enforce clean repository structure, naming conventions, and Git workflows.
  - Formulate the top-level architectural blueprint and signal interface definitions connecting CPU, cache modules, and main memory.
  - Coordinate integration across all submodule owners and resolve interface discrepancies.
  - Maintain documentation consistency across `README.md`, `ARCHITECTURE.md`, and design notes.
- **Key Deliverables:**
  - Standardized repository skeleton (`rtl/`, `tb/`, `sim/`, `build/`, `waveforms/`, `results/`, `docs/`).
  - System specification and bit-decomposition documentation.
  - Module port list and timing contracts for shared buses.
  - Final project integration and architectural review.

---

### 2.2 Keshav — Two-Way Set-Associative Cache RTL
- **Scope & Objectives:**
  - Implement synthesizable Verilog for the 2-way set-associative cache datapath.
  - Design the dual-way storage architecture (Way 0 and Way 1 arrays: Valid, Tag, and Data).
  - Implement concurrent dual-tag comparators and hit/miss multiplexing logic.
  - Interface Way 0 and Way 1 selection signals with Shitanshu's LRU and FSM controllers.
- **Key Deliverables:**
  - `rtl/cache_2way_datapath.v` (or top-level `rtl/cache_2way.v`).
  - Concurrent tag comparison and hit generation logic for `Hit_Way0` and `Hit_Way1`.
  - Data forwarding multiplexers routing accessed way data to the CPU output port.

---

### 2.3 Shitanshu — LRU Replacement Logic and Cache FSM
- **Scope & Objectives:**
  - Design the 1-bit per set Least Recently Used (LRU) state registers and update logic.
  - Implement victim line selection rules: allocate invalid lines first; on full set, evict based on the LRU bit.
  - Model the master Cache Controller Finite State Machine (FSM) managing `IDLE`, `COMPARE_TAG`, `MEM_WAIT`, and `UPDATE` cycles.
  - Generate control strobes for tag/data write-enables, memory request lines, and processor handshake signals.
- **Key Deliverables:**
  - `rtl/lru_controller.v` (1-bit LRU management per set).
  - `rtl/cache_controller_fsm.v` (synchronous control state machine).
  - Handshake logic coordinating CPU stalls and main memory read allocations.

---

### 2.4 Shivam — Direct-Mapped Cache RTL
- **Scope & Objectives:**
  - Implement synthesizable Verilog for the 8-line direct-mapped cache module.
  - Construct the single-bank storage array (8 lines: 1-bit Valid, 5-bit Tag, 8-bit Data).
  - Implement single-cycle tag comparison logic and hit/miss generation.
  - Construct simple line replacement logic (direct eviction on miss without associative arbitration).
- **Key Deliverables:**
  - `rtl/cache_direct_mapped.v`.
  - Direct index decoder logic (`address[2:0]`) and 5-bit tag comparator (`address[7:3]`).
  - Synchronous read/write logic for cache lines and memory bus signaling.

---

### 2.5 Kaavya — Testbenches and Simulation
- **Scope & Objectives:**
  - Develop modular testbenches for unit-level and system-level verification.
  - Implement a behavioral model for the 256 × 8-bit synchronous main memory (`tb/main_mem_model.v`).
  - Construct synthetic memory access benchmarks:
    - *Sequential access patterns* (spatial locality evaluation).
    - *Repeated loop patterns* (temporal locality evaluation).
    - *Thrashing patterns* (forcing conflict misses at identical index bits to contrast direct-mapped vs. 2-way).
  - Automate simulation runs using Icarus Verilog (`iverilog`) and extract hit/miss counters.
  - Verify timing waveforms via GTKWave.
- **Key Deliverables:**
  - `tb/tb_cache_direct_mapped.v` and `tb/tb_cache_2way.v`.
  - `tb/main_mem_model.v`.
  - `sim/run_sim.sh` (or `Makefile`).
  - Performance metric tables and waveform captures (`waveforms/`, `results/`).

---

## 3. Communication & Integration Protocol

1. **Branching Strategy:**  
   - Main branch (`main`) remains clean and compilation-ready.
   - Development occurs on feature branches (e.g., `feat/direct-mapped`, `feat/2way-cache`, `feat/lru-fsm`, `feat/testbenches`).
2. **Interface Alignment:**  
   - Prior to coding RTL, Keshav, Shitanshu, and Shivam must review and sign off on module port names defined in `docs/ARCHITECTURE.md`.
3. **Verification Sign-Off:**  
   - Any RTL module submitted for merge must be validated against Kaavya's baseline test vectors.

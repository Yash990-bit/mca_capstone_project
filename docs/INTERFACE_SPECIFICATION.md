# Hardware Interface Specification & Memory Protocol

> **Document Status:** Authoritative Interface Agreement for Phase 1  
> **Target Audience:** Keshav (2-Way), Shitanshu (LRU & FSM), Shivam (Direct-Mapped), Kaavya (Verification)  
> **Author:** Yash (Project Lead / System Architect)

---

## 1. System Bus Interfaces & Pinouts

To guarantee seamless integration, both the **Direct-Mapped Cache** and the **2-Way Set-Associative Cache** must adhere to the exact same CPU-side and Memory-side port definitions.

### 1.1 CPU / Master Interface

| Signal Name | Direction | Width | Description |
|:---|:---:|:---:|:---|
| `clk` | Input | 1 bit | System clock (positive edge triggered). |
| `rst_n` | Input | 1 bit | Active-low asynchronous/synchronous reset. |
| `req_valid` | Input | 1 bit | Asserted by CPU when requesting a memory transaction. |
| `req_addr` | Input | 8 bits | 8-bit memory target byte address (`[7:0]`). |
| `req_wr_en` | Input | 1 bit | `1` = Write transaction, `0` = Read transaction. |
| `req_wdata` | Input | 8 bits | 8-bit data word to be written to memory/cache. |
| `resp_rdata` | Output | 8 bits | 8-bit data word returned to CPU on read operations. |
| `resp_valid` | Output | 1 bit | Asserted high by cache when read/write transaction completes. |
| `cache_hit` | Output | 1 bit | High if transaction resolved in cache; Low if miss occurred. |
| `busy` | Output | 1 bit | Asserted while cache controller is handling miss/stall. |

---

### 1.2 Backing Memory (256 × 8-bit RAM) Interface

| Signal Name | Direction | Width | Description |
|:---|:---:|:---:|:---|
| `mem_req` | Output | 1 bit | Asserted by cache controller to request main memory access. |
| `mem_wr_en` | Output | 1 bit | `1` = Write to main memory, `0` = Read from main memory. |
| `mem_addr` | Output | 8 bits | 8-bit memory address driven to main memory. |
| `mem_wdata` | Output | 8 bits | 8-bit data word sent to main memory on write. |
| `mem_rdata` | Input | 8 bits | 8-bit data word returned by main memory on read. |
| `mem_ready` | Input | 1 bit | Asserted by main memory when read/write cycle finishes. |

---

## 2. Memory & Write Policy Definition

### 2.1 Standardized Write Policy
- **Policy Selection:** **Write-Through with No-Write-Allocate**
- **Rationale for College Project:**
  1. *Eliminates Dirty Bits:* No complex dirty bit tracking or write-back eviction buffers needed.
  2. *Data Coherence:* Backing main memory always holds the newest data on writes.
  3. *Equal Baseline:* Both Shivam's Direct-Mapped and Keshav/Shitanshu's 2-Way cache can implement identical write behavior without architectural asymmetry.

### 2.2 Operational Behavior

#### A. Read Hit
1. CPU asserts `req_valid = 1`, `req_wr_en = 0`, and `req_addr`.
2. Cache indexes into set/line, compares tag, and detects a match on a valid line.
3. Cache asserts `cache_hit = 1`, drives `resp_rdata`, and asserts `resp_valid = 1`.
4. LRU bit is updated (for 2-way cache).
5. Transaction completes in 1 clock cycle without main memory access (`mem_req = 0`).

#### B. Read Miss
1. Tag comparison reveals no valid match (`cache_hit = 0`).
2. Controller asserts `busy = 1`.
3. Controller asserts `mem_req = 1`, `mem_wr_en = 0`, and `mem_addr = req_addr`.
4. Main memory processes the read and returns `mem_rdata` with `mem_ready = 1`.
5. Cache line is refilled:
   - Direct-mapped: Overwrites target indexed line.
   - 2-Way: Selects victim line via LRU unit, writes new tag/data, sets valid bit, updates LRU.
6. Cache drives `resp_rdata = mem_rdata`, asserts `resp_valid = 1`, and de-asserts `busy`.

#### C. Write Hit
1. CPU asserts `req_valid = 1`, `req_wr_en = 1`, `req_addr`, and `req_wdata`.
2. Cache finds matching line (`cache_hit = 1`).
3. Under Write-Through policy:
   - Cache updates its internal line data with `req_wdata`.
   - Simultaneously drives write to backing memory: `mem_req = 1`, `mem_wr_en = 1`, `mem_addr = req_addr`, `mem_wdata = req_wdata`.
4. When `mem_ready = 1`, asserts `resp_valid = 1` and updates LRU bit.

#### D. Write Miss (No-Write-Allocate)
1. CPU asserts `req_valid = 1`, `req_wr_en = 1`.
2. Cache does not contain the block (`cache_hit = 0`).
3. Under No-Write-Allocate:
   - The cache does **not** allocate a cache line.
   - The write bypasses cache directly to main memory: `mem_req = 1`, `mem_wr_en = 1`, `mem_addr = req_addr`, `mem_wdata = req_wdata`.
4. When `mem_ready = 1`, transaction finishes with `resp_valid = 1`.

---

## 3. Submodule Interface Specifications

### 3.1 2-Way Cache Datapath (`rtl/cache_2way.v`) — Keshav
```verilog
module cache_2way (
    input  wire       clk,
    input  wire       rst_n,
    // CPU Interface
    input  wire       req_valid,
    input  wire [7:0] req_addr,
    input  wire       req_wr_en,
    input  wire [7:0] req_wdata,
    output wire [7:0] resp_rdata,
    output wire       resp_valid,
    output wire       cache_hit,
    output wire       busy,
    // Main Memory Interface
    output wire       mem_req,
    output wire       mem_wr_en,
    output wire [7:0] mem_addr,
    output wire [7:0] mem_wdata,
    input  wire [7:0] mem_rdata,
    input  wire       mem_ready
);
```

### 3.2 LRU Controller (`rtl/lru_controller.v`) — Shitanshu
```verilog
module lru_controller (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] set_index,       // 2-bit set index (4 sets)
    input  wire       access_valid,    // High on hit or refill
    input  wire       access_way,      // 0 = Way 0 accessed, 1 = Way 1 accessed
    input  wire       way0_valid,      // Valid status of Way 0
    input  wire       way1_valid,      // Valid status of Way 1
    output wire       victim_way,      // 0 = Replace Way 0, 1 = Replace Way 1
    output wire [3:0] lru_state_all    // Debug: output of all 4 set LRU bits
);
```

### 3.3 Direct-Mapped Cache (`rtl/cache_direct.v`) — Shivam
```verilog
module cache_direct (
    input  wire       clk,
    input  wire       rst_n,
    // CPU Interface
    input  wire       req_valid,
    input  wire [7:0] req_addr,
    input  wire       req_wr_en,
    input  wire [7:0] req_wdata,
    output wire [7:0] resp_rdata,
    output wire       resp_valid,
    output wire       cache_hit,
    output wire       busy,
    // Main Memory Interface
    output wire       mem_req,
    output wire       mem_wr_en,
    output wire [7:0] mem_addr,
    output wire [7:0] mem_wdata,
    input  wire [7:0] mem_rdata,
    input  wire       mem_ready
);
```

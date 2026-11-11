# Direct-Mapped Cache Architecture & Interface Specification

> **Module:** `cache_direct.v`  
> **Testbench:** `tb_direct.v`  
> **Author / Assigned Member:** Shivam (RTL Engineer — Direct-Mapped Cache)  
> **Project:** Design and Performance Analysis of a 2-Way Set-Associative Cache with LRU Replacement Compared with a Direct-Mapped Cache  
> **Status:** Fully Implemented & Verified with 100% Test Pass Rate

---

## 1. Architectural Overview & Configuration

The **Direct-Mapped Cache** acts as the baseline cache architecture for the project. Both the Direct-Mapped Cache and the 2-Way Set-Associative Cache are constrained to **identical total storage capacities (8 bytes)** and operate across an **8-bit address space ($2^8 = 256$ bytes)** to provide a fair, rigorous comparative evaluation.

### Key Parameters:
| Parameter | Specification | Explanation |
|:---|:---:|:---|
| **Address Width** | 8 bits (`[7:0]`) | Supports a 256-byte byte-addressable main memory |
| **Data Width** | 8 bits (`[7:0]`) | 1-byte data word per memory access |
| **Cache Capacity** | 8 bytes | Storage for 8 data entries |
| **Block / Line Size** | 1 byte | Single-byte transfers (Offset = $\log_2(1) = 0$ bits) |
| **Number of Cache Lines** | 8 lines | $2^3 = 8$ indexed locations |
| **Associativity** | 1-Way (Direct-Mapped) | Each memory address maps to exactly one line |
| **Write Policy** | Write-Through / No-Write-Allocate | Consistent with 2-way cache baseline |
| **Replacement Policy** | Direct Replacement | Direct overwrite on conflict miss |

---

## 2. Address Bit Decomposition

Because the block size is **1 byte**, the intra-block byte offset requires 0 bits ($\log_2(1) = 0$).  
All 8 address bits are partitioned between the **Line Index** and the **Tag**:

$$\text{Line Index Bits} = \log_2(8 \text{ lines}) = 3 \text{ bits} \implies \text{address}[2:0]$$
$$\text{Tag Bits} = 8 - 3 - 0 = 5 \text{ bits} \implies \text{address}[7:3]$$

```
+------------------------------------+--------------------------+
|            Tag (5 bits)            |    Line Index (3 bits)   |
|            address[7:3]            |       address[2:0]       |
+------------------------------------+--------------------------+
  Bit 7   Bit 6   Bit 5   Bit 4   Bit 3   Bit 2   Bit 1   Bit 0
```

### Worked Address Mapping Examples:

#### Example 1: Address `0x12` (`8'b00010_010`)
- **Binary:** `00010 010`
- **Tag:** `req_addr[7:3]` = `5'b00010` (Decimal 2)
- **Line Index:** `req_addr[2:0]` = `3'b010` (Decimal 2)
- **Mapping:** This address maps exclusively to **Cache Line 2**.

#### Example 2: Address `0x32` (`8'b00110_010`)
- **Binary:** `00110 010`
- **Tag:** `req_addr[7:3]` = `5'b00110` (Decimal 6)
- **Line Index:** `req_addr[2:0]` = `3'b010` (Decimal 2)
- **Mapping:** This address **also maps to Cache Line 2** because both have `index = 3'b010`.
- **Conflict Miss Analysis:** If `0x12` resides in Line 2, and CPU requests `0x32`, the line index matches, but the tag comparison fails ($6 \neq 2$). Line 2 is evicted and overwritten with data from `0x32`. If the CPU subsequently requests `0x12` again, another conflict miss occurs, illustrating ping-pong thrashing in direct-mapped topologies.

#### Example 3: Address `0x88` (`8'b10001_000`)
- **Binary:** `10001 000`
- **Tag:** `req_addr[7:3]` = `5'b10001` (Decimal 17)
- **Line Index:** `req_addr[2:0]` = `3'b000` (Decimal 0)
- **Mapping:** Maps to **Cache Line 0**.

---

## 3. Module Ports & Hardware Interface

Module declaration matches [`docs/INTERFACE_SPECIFICATION.md`](INTERFACE_SPECIFICATION.md) exactly:

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
    // Backing Memory Interface
    output wire       mem_req,
    output wire       mem_wr_en,
    output wire [7:0] mem_addr,
    output wire [7:0] mem_wdata,
    input  wire [7:0] mem_rdata,
    input  wire       mem_ready
);
```

### Port Descriptions:

| Signal | Direction | Width | Description |
|:---|:---:|:---:|:---|
| `clk` | Input | 1 bit | System clock, positive-edge triggered |
| `rst_n` | Input | 1 bit | Active-low asynchronous reset |
| `req_valid` | Input | 1 bit | CPU request strobe; asserted when initiating a read or write |
| `req_addr` | Input | 8 bits | Target physical byte address (`[7:0]`) |
| `req_wr_en` | Input | 1 bit | Transaction type: `0` = Read, `1` = Write |
| `req_wdata` | Input | 8 bits | Write data word from CPU |
| `resp_rdata` | Output | 8 bits | Read data word returned to CPU |
| `resp_valid` | Output | 1 bit | High when transaction completes (1-cycle pulse or handshake) |
| `cache_hit` | Output | 1 bit | High if request was resolved in cache; low on miss |
| `busy` | Output | 1 bit | High when cache is stalling CPU while accessing backing memory |
| `mem_req` | Output | 1 bit | Backing memory request strobe |
| `mem_wr_en` | Output | 1 bit | Memory operation: `0` = Read fetch, `1` = Write store |
| `mem_addr` | Output | 8 bits | Physical memory address driven to main memory |
| `mem_wdata` | Output | 8 bits | Data word driven to main memory on write |
| `mem_rdata` | Input | 8 bits | Data byte returned from main memory |
| `mem_ready` | Input | 1 bit | Ready signal from main memory indicating read/write completion |

---

## 4. Internal Storage Organization

The direct-mapped cache comprises three hardware arrays:
1. **`data_array [0:7]`**: 8 registers of 8 bits each (64 bits data storage total).
2. **`tag_array [0:7]`**: 8 registers of 5 bits each (40 bits tag storage total).
3. **`valid_array [0:7]`**: 8 registers of 1 bit each (8 valid bits total).

```
Index [2:0]   Valid (1b)     Tag [4:0]      Data [7:0]
  3'b000      valid[0]       tag[0]         data[0]
  3'b001      valid[1]       tag[1]         data[1]
  3'b010      valid[2]       tag[2]         data[2]
  3'b011      valid[3]       tag[3]         data[3]
  3'b100      valid[4]       tag[4]         data[4]
  3'b101      valid[5]       tag[5]         data[5]
  3'b110      valid[6]       tag[6]         data[6]
  3'b111      valid[7]       tag[7]         data[7]
```

---

## 5. Operation & Control Finite State Machine (FSM)

The controller uses a clean 3-state FSM:

```
               +-------------------------------------------+
               |                STATE_IDLE                 |
               +-------------------------------------------+
                 |                       |               ^
   Read Miss     |           Write Req   |               |
   (hit == 0)    v           (wr_en == 1)v               | mem_ready == 1
               +---------------+   +-------------------+ |
               |STATE_READ_WAIT|   | STATE_WRITE_WAIT  | |
               +---------------+   +-------------------+ |
                 |                       |               |
                 +-----------+-----------+---------------+
                             | mem_ready == 1
                             v
                        (Refill / Acknowledge)
```

### 1. Read Hit:
- When `req_valid = 1`, `req_wr_en = 0`, and `hit_comb = 1`:
- `resp_valid = 1`, `resp_rdata = data_array[index]`, `cache_hit = 1`, `busy = 0`.
- Handled immediately within 1 cycle without main memory request (`mem_req = 0`).

### 2. Read Miss:
- When `req_valid = 1`, `req_wr_en = 0`, and `hit_comb = 0`:
- Controller latches `latched_addr <= req_addr`, asserts `busy = 1`, and drives `mem_req = 1`, `mem_wr_en = 0`, `mem_addr = req_addr`.
- Controller moves to `STATE_READ_WAIT`.
- When backing memory returns data with `mem_ready = 1`:
  - `data_array[latched_addr[2:0]] <= mem_rdata`
  - `tag_array[latched_addr[2:0]]  <= latched_addr[7:3]`
  - `valid_array[latched_addr[2:0]]<= 1'b1`
  - Drives `resp_rdata = mem_rdata`, `resp_valid = 1`, `cache_hit = 0`, and clears `busy = 0`.
  - Returns to `STATE_IDLE`.

### 3. Write Hit (Write-Through):
- When `req_valid = 1`, `req_wr_en = 1`, and `hit_comb = 1`:
- Cache line data is updated immediately: `data_array[index] <= req_wdata`.
- Latch address and data, enter `STATE_WRITE_WAIT`.
- Assert `mem_req = 1`, `mem_wr_en = 1`, `mem_addr = req_addr`, `mem_wdata = req_wdata`, `busy = 1`.
- When `mem_ready = 1`: asserts `resp_valid = 1`, `cache_hit = 1`, and returns to `STATE_IDLE`.
- Both cache and main memory contain identical up-to-date values.

### 4. Write Miss (No-Write-Allocate):
- When `req_valid = 1`, `req_wr_en = 1`, and `hit_comb = 0`:
- Cache lines are **not** updated or allocated.
- Write request passes directly to main memory: `mem_req = 1`, `mem_wr_en = 1`, `mem_addr = req_addr`, `mem_wdata = req_wdata`.
- When `mem_ready = 1`: asserts `resp_valid = 1`, `cache_hit = 0`, and returns to `STATE_IDLE`.

---

## 6. Verification Results

Simulation was executed using Icarus Verilog (`iverilog`) and tested against all 9 mandatory verification scenarios:

```
===============================================================================
STARTING VERIFICATION SUITE: DIRECT-MAPPED CACHE BASELINE
RTL: rtl/cache_direct.v | Testbench: tb/tb_direct.v
Author: Shivam (Direct-Mapped RTL Owner)
===============================================================================

--- [TEST CASE 9]: RESET BEHAVIOR AND INITIALIZATION ---
[PASS] Reset Initialization: All 8 valid bits cleared, state is IDLE.

--- [TEST CASE 1]: COLD READ MISS ---
[PASS] Cold Read Miss (Addr 0x12) | Addr: 0x12 (Tag=2, Idx=2) | Data: 0x48 | Hit: 0

--- [TEST CASE 2]: REPEATED READ HIT ---
[PASS] Repeated Read Hit (Addr 0x12) | Addr: 0x12 (Tag=2, Idx=2) | Data: 0x48 | Hit: 1
[PASS] Second Read Hit  (Addr 0x12) | Addr: 0x12 (Tag=2, Idx=2) | Data: 0x48 | Hit: 1

--- [TEST CASE 3 & 4]: SAME INDEX MAPPING & CONFLICT MISS ---
Addr 0x12: Tag=2, Index=2 | Addr 0x32: Tag=6, Index=2
[PASS] Conflict Miss: Overwriting Line 2 (Addr 0x32) | Addr: 0x32 (Tag=6, Idx=2) | Data: 0x68 | Hit: 0
[PASS] Subsequent Read Hit on New Line (Addr 0x32) | Addr: 0x32 (Tag=6, Idx=2) | Data: 0x68 | Hit: 1
[PASS] Conflict Miss: Evicting Line 2 Back to Addr 0x12 | Addr: 0x12 (Tag=2, Idx=2) | Data: 0x48 | Hit: 0
[PASS] Subsequent Read Hit on Refilled Addr 0x12 | Addr: 0x12 (Tag=2, Idx=2) | Data: 0x48 | Hit: 1

--- [TEST CASE 5]: POPULATING ALL 8 CACHE LINES (NO CONFLICTS) ---
[PASS] Cold Miss Fill Line 0 (0x00) | Addr: 0x00 (Tag=0, Idx=0) | Data: 0x5a | Hit: 0
[PASS] Cold Miss Fill Line 1 (0x01) | Addr: 0x01 (Tag=0, Idx=1) | Data: 0x5b | Hit: 0
[PASS] Cold Miss Fill Line 2 (0x02) | Addr: 0x02 (Tag=0, Idx=2) | Data: 0x58 | Hit: 0
[PASS] Cold Miss Fill Line 3 (0x03) | Addr: 0x03 (Tag=0, Idx=3) | Data: 0x59 | Hit: 0
[PASS] Cold Miss Fill Line 4 (0x04) | Addr: 0x04 (Tag=0, Idx=4) | Data: 0x5e | Hit: 0
[PASS] Cold Miss Fill Line 5 (0x05) | Addr: 0x05 (Tag=0, Idx=5) | Data: 0x5f | Hit: 0
[PASS] Cold Miss Fill Line 6 (0x06) | Addr: 0x06 (Tag=0, Idx=6) | Data: 0x5c | Hit: 0
[PASS] Cold Miss Fill Line 7 (0x07) | Addr: 0x07 (Tag=0, Idx=7) | Data: 0x5d | Hit: 0

--- [TEST CASE 6]: READ DATA CORRECTNESS & 100% HIT VERIFICATION ---
[PASS] Read Hit Verify Line 0 (0x00) | Addr: 0x00 (Tag=0, Idx=0) | Data: 0x5a | Hit: 1
[PASS] Read Hit Verify Line 1 (0x01) | Addr: 0x01 (Tag=0, Idx=1) | Data: 0x5b | Hit: 1
[PASS] Read Hit Verify Line 2 (0x02) | Addr: 0x02 (Tag=0, Idx=2) | Data: 0x58 | Hit: 1
[PASS] Read Hit Verify Line 3 (0x03) | Addr: 0x03 (Tag=0, Idx=3) | Data: 0x59 | Hit: 1
[PASS] Read Hit Verify Line 4 (0x04) | Addr: 0x04 (Tag=0, Idx=4) | Data: 0x5e | Hit: 1
[PASS] Read Hit Verify Line 5 (0x05) | Addr: 0x05 (Tag=0, Idx=5) | Data: 0x5f | Hit: 1
[PASS] Read Hit Verify Line 6 (0x06) | Addr: 0x06 (Tag=0, Idx=6) | Data: 0x5c | Hit: 1
[PASS] Read Hit Verify Line 7 (0x07) | Addr: 0x07 (Tag=0, Idx=7) | Data: 0x5d | Hit: 1

--- [TEST CASE 7]: WRITE HIT (WRITE-THROUGH) ---
[PASS] Write Hit (Addr 0x03, Data 0xDE) | Addr: 0x03 | WData: 0xde | Hit: 1 | MainMem: 0xde
[PASS] Subsequent Read Hit to Written Addr (0x03) | Addr: 0x03 (Tag=0, Idx=3) | Data: 0xde | Hit: 1

--- [TEST CASE 8]: WRITE MISS (NO-WRITE-ALLOCATE) ---
[PASS] Write Miss (Addr 0x88, Data 0xBE) | Addr: 0x88 | WData: 0xbe | Hit: 0 | MainMem: 0xbe
[PASS] Verify Line 0 Unchanged by Write Miss | Addr: 0x00 (Tag=0, Idx=0) | Data: 0x5a | Hit: 1
[PASS] Read Miss on 0x88 (Fetches Written 0xBE from Memory) | Addr: 0x88 (Tag=17, Idx=0) | Data: 0xbe | Hit: 0
[PASS] Subsequent Read Hit on 0x88 | Addr: 0x88 (Tag=17, Idx=0) | Data: 0xbe | Hit: 1

--- [TEST CASE 9]: RE-TEST RESET INVALIDATION ---
[PASS] Cold Miss After Reset on Previously Cached Addr | Addr: 0x88 (Tag=17, Idx=0) | Data: 0xbe | Hit: 0

===============================================================================
VERIFICATION SUMMARY FOR DIRECT-MAPPED CACHE:
Total Tests Executed : 31
Tests Passed         : 31
Tests Failed         : 0
>>> ALL TESTS PASSED SUCCESSFULLY! DIRECT-MAPPED CACHE MEETS ALL REQUIREMENTS. <<<
===============================================================================
```

---

## 7. Direct-Mapped vs. 2-Way Set-Associative Viva Guide

| Architectural Metric | Direct-Mapped Cache (Shivam) | 2-Way Set-Associative Cache (Keshav + Shitanshu) |
|:---|:---|:---|
| **Mapping Flexibility** | Fixed: Each address maps to **exactly 1 line** (`index = addr[2:0]`). | Flexible: Each address can reside in **either Way 0 or Way 1** of a set (`set = addr[1:0]`). |
| **Index Bits** | 3 bits (`address[2:0]`, 8 lines) | 2 bits (`address[1:0]`, 4 sets) |
| **Tag Bits** | 5 bits (`address[7:3]`) | 6 bits (`address[7:2]`) |
| **Comparators Required** | **1 comparator** (5-bit) | **2 parallel comparators** (6-bit each) |
| **Replacement Policy** | **None required**: Direct eviction upon index collision. | **LRU required**: 1 bit per set (4 LRU bits total) to track least recently used way. |
| **Conflict Misses** | **High**: Alternating accesses to addresses with the same index cause continuous thrashing. | **Low**: Two competing addresses with the same set index can reside concurrently in Way 0 and Way 1. |
| **Hardware Complexity** | Minimal area, simple single-comparator logic, fastest access path. | Moderate area, dual comparators, way selection MUX, LRU registers and update logic. |
| **Access Latency** | Shortest critical path. | Slightly longer critical path due to parallel tag comparisons and way multiplexing. |


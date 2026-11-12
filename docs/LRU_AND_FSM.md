# LRU Replacement & Cache Controller FSM Documentation

> **Modules Covered:** `rtl/lru_controller.v` & `rtl/cache_fsm.v`  
> **Integration:** Integrated with Keshav's `rtl/cache_2way.v`  
> **Verification:** `tb/tb_lru_fsm.v` (24/24 tests passing) & `tb/tb_cache_2way_keshav.v` (26/26 checks passing)

---

## 1. LRU Replacement Controller (`rtl/lru_controller.v`)

### 1.1 State Convention (1 Bit per Set)
The 2-way set-associative cache has **4 sets**, each with **2 ways** (Way 0 and Way 1). A single flip-flop per set (`reg [3:0] lru_bits`) is sufficient to track which way was **Least Recently Used**:

| `lru_bits[set]` | Meaning | Next Victim (if both ways valid) |
|:---:|:---|:---:|
| `0` | Way 0 was accessed earlier than Way 1 (**Way 0 is LRU**) | **Way 0** (`victim_way = 0`) |
| `1` | Way 1 was accessed earlier than Way 0 (**Way 1 is LRU**) | **Way 1** (`victim_way = 1`) |

### 1.2 Update & Victim Selection Rules
- **Reset (`!rst_n`):** `lru_bits <= 4'b0000` (all sets default to Way 0 as LRU).
- **On Access (`access_valid == 1` at posedge `clk`):**
  - If Way 0 is accessed (`access_way == 0`), Way 1 becomes the least recently used: `lru_bits[set_index] <= 1'b1`.
  - If Way 1 is accessed (`access_way == 1`), Way 0 becomes the least recently used: `lru_bits[set_index] <= 1'b0`.
  - In hardware, this simplifies to: `lru_bits[set_index] <= ~access_way`.
- **Victim Selection (`victim_way`, Combinational):**
  1. **Invalid-Way Preference:** Never evict valid data if an empty slot exists:
     - If `!way0_valid` $\rightarrow$ select **Way 0** (`0`).
     - Else if `!way1_valid` $\rightarrow$ select **Way 1** (`1`).
  2. **LRU Eviction:** If both `way0_valid` and `way1_valid` are `1`, select `lru_bits[set_index]`.

---

## 2. Mandatory Replacement Trace Walkthrough (`0x00 -> 0x10 -> 0x00 -> 0x20`)

All three addresses have `address[1:0] == 2'b00`, so all three map to **Set 0**:
- `0x00` = `8'b0000_0000` (Tag = `0x00`, Set = `0`)
- `0x10` = `8'b0001_0000` (Tag = `0x04`, Set = `0`)
- `0x20` = `8'b0010_0000` (Tag = `0x08`, Set = `0`)

| Step | Address | Event | Way 0 | Way 1 | `LRU[0]` After | Explanation |
|:---:|:---:|:---|:---:|:---:|:---:|:---|
| **Init** | — | Reset | Invalid | Invalid | `0` | Cache empty |
| **1** | `0x00` | **Cold Miss** | **`0x00`** (V=1) | Invalid | `1` | Way 0 is invalid, so `0x00` goes to Way 0. Way 1 becomes LRU (`1`). |
| **2** | `0x10` | **Cold Miss** | `0x00` (V=1) | **`0x10`** (V=1) | `0` | Way 1 is invalid, so `0x10` goes to Way 1. Way 0 becomes LRU (`0`). |
| **3** | `0x00` | **Read Hit (Way 0)** | **`0x00`** (V=1) | `0x10` (V=1) | `1` | `0x00` is accessed again in Way 0! Way 1 (`0x10`) becomes LRU (`1`). |
| **4** | `0x20` | **Conflict Miss** | `0x00` (V=1) | **`0x20`** (V=1) | `0` | Both ways are valid and `LRU[0] == 1`, so **Way 1 (`0x10`) is evicted** and `0x20` takes Way 1. **`0x00` stays safe in Way 0.** |

**Why was `0x10` evicted instead of `0x00`?**  
Even though `0x00` arrived earlier than `0x10`, Step 3 accessed `0x00` again, making `0x00` the **Most Recently Used (MRU)** block and `0x10` the **Least Recently Used (LRU)** block.

---

## 3. Cache Controller FSM (`rtl/cache_fsm.v`)

### 3.1 State Encoding & Transitions

| State | Code | `busy` | Outputs Asserted | Next State Transition |
|:---|:---:|:---:|:---|:---|
| `STATE_IDLE` | `3'b000` | `0` | None | `req_valid == 1` $\rightarrow$ `STATE_LOOKUP` (latches `req_wr_en`) |
| `STATE_LOOKUP` | `3'b001` | `1` | None | `!latched_wr_en && cache_hit` $\rightarrow$ `STATE_HIT_RESPONSE`; else $\rightarrow$ `STATE_MEMORY_WAIT` |
| `STATE_HIT_RESPONSE` | `3'b010` | `1` | `resp_valid = 1` | Unconditionally $\rightarrow$ `STATE_IDLE` |
| `STATE_MEMORY_WAIT` | `3'b011` | `1` | `mem_req = 1`, `mem_wr_en = latched_wr_en` | When `mem_ready == 1`: if read $\rightarrow$ `STATE_REFILL`; if write $\rightarrow$ `STATE_RESPONSE` |
| `STATE_REFILL` | `3'b100` | `1` | `refill_en = 1` | Unconditionally $\rightarrow$ `STATE_RESPONSE` |
| `STATE_RESPONSE` | `3'b101` | `1` | `resp_valid = 1` | Unconditionally $\rightarrow$ `STATE_IDLE` |

### 3.2 How Overlapping Requests Are Prevented
- `busy` is high (`1`) in every state except `STATE_IDLE`.
- `req_wr_en` is latched (`latched_wr_en`) only during `STATE_IDLE && req_valid`, so external bus changes during `MEMORY_WAIT` cannot corrupt an in-flight read or write.

---

## 4. Viva Quick-Reference (Beginner-Friendly)
- **Why 1 bit for 2-way LRU?** With 2 ways, only one can be "most recent" and the other "least recent", so 2 states (`0` or `1`) = 1 flip-flop per set (4 flip-flops total).
- **Why prefer invalid ways before checking LRU?** On cold start, if Way 0 is filled (`LRU=1`) and Way 1 is still empty, we must fill the empty Way 1 rather than overwriting anything.
- **How does Write-Through + No-Write-Allocate affect FSM?** Writes always go to `STATE_MEMORY_WAIT` (`mem_wr_en = 1`) and skip `STATE_REFILL` when returning to `STATE_RESPONSE`.

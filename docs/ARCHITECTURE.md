# Microarchitecture Specification (Planned Design)

> **Document Status: Planned Architecture & Preliminary Specification**  
> *This document details the planned hardware architecture for the project. The Verilog RTL, controller state machines, and verification testbenches are not yet implemented.*

---

## 1. System Overview & Hierarchy

The memory subsystem is designed around an 8-bit byte-addressable address space ($2^8 = 256$ bytes). The system connects a processor/host model to one of two interchangeable cache modules, which in turn communicate with an off-chip/main memory module.

```
       +---------------------------------------------+
       |                 CPU / Master                |
       +---------------------------------------------+
             |                 ^                ^
             | [7:0] addr      | [7:0] rdata    | hit / ready
             | [7:0] wdata     |                |
             | wr_en, rd_en    |                |
             v                 |                |
       +---------------------------------------------+
       |               Cache Subsystem               |
       |  (Direct-Mapped OR 2-Way Set-Associative)  |
       +---------------------------------------------+
             |                 ^
             | mem_addr        | mem_rdata
             | mem_wdata       | mem_ready
             | mem_read/write  |
             v                 |
       +---------------------------------------------+
       |         Main Memory (256 x 8-bit RAM)       |
       +---------------------------------------------+
```

---

## 2. Address Bit Decomposition

Memory address width: **8 bits** (`address[7:0]`).  
Cache line (block) size: **1 byte**.

Because each cache block contains exactly 1 byte, the number of intra-block offset bits is:
$$\text{Offset bits} = \log_2(\text{Block Size in Bytes}) = \log_2(1) = 0 \text{ bits}$$

Every bit in the address is therefore allocated strictly to either the **Index** or the **Tag**.

### 2.1 Direct-Mapped Cache Address Breakdown
- **Total Capacity:** 8 bytes
- **Number of Lines:** 8 lines
- **Line Index Bits:** $\log_2(8) = 3 \text{ bits}$ $\rightarrow$ `address[2:0]`
- **Tag Bits:** $8 - 3 - 0 = 5 \text{ bits}$ $\rightarrow$ `address[7:3]`

```
+-----------------------------+-----------------------+
|          Tag (5 bits)       |   Line Index (3 bits) |
|         address[7:3]        |       address[2:0]    |
+-----------------------------+-----------------------+
```

### 2.2 Two-Way Set-Associative Cache Address Breakdown
- **Total Capacity:** 8 bytes (divided into 2 ways)
- **Number of Ways:** 2 lines per set
- **Number of Sets:** $\frac{\text{Total Lines}}{\text{Ways}} = \frac{8}{2} = 4 \text{ sets}$
- **Set Index Bits:** $\log_2(4) = 2 \text{ bits}$ $\rightarrow$ `address[1:0]`
- **Tag Bits:** $8 - 2 - 0 = 6 \text{ bits}$ $\rightarrow$ `address[7:2]`

```
+-----------------------------------+--------------------+
|            Tag (6 bits)           | Set Index (2 bits) |
|            address[7:2]           |    address[1:0]    |
+-----------------------------------+--------------------+
```

---

## 3. Direct-Mapped Cache Architecture

In a direct-mapped cache, every block in main memory maps to exactly one specific line in the cache, determined by:
$$\text{Line} = \text{address[2:0]}$$

### 3.1 Internal Storage Elements
The direct-mapped cache comprises an array of 8 entries, where each entry stores:
- **Valid Bit ($V$):** 1 bit (indicates whether the entry contains valid cached data).
- **Tag Field:** 5 bits (`tag[4:0]`).
- **Data Field:** 8 bits (`data[7:0]`).

```
Line Index     Valid      Tag [4:0]       Data [7:0]
  3'b000        [ ]       [       ]       [        ]
  3'b001        [ ]       [       ]       [        ]
  3'b010        [ ]       [       ]       [        ]
  3'b011        [ ]       [       ]       [        ]
  3'b100        [ ]       [       ]       [        ]
  3'b101        [ ]       [       ]       [        ]
  3'b110        [ ]       [       ]       [        ]
  3'b111        [ ]       [       ]       [        ]
```

### 3.2 Hit and Miss Determination
1. The 3-bit line index `address[2:0]` indexes into the array.
2. The stored tag is read out and compared against `address[7:3]`.
3. A **Hit** occurs when:
   $$\text{Hit} = \text{Valid}[\text{index}] \land (\text{Stored\_Tag}[\text{index}] == \text{address}[7:3])$$
4. A **Miss** occurs if either $\text{Valid} == 0$ or the tag comparison evaluates to false.
5. On a miss, the cache controller stalls the CPU, reads the requested byte from main memory at `address[7:0]`, overwrites the existing entry with the fetched data, updates the tag to `address[7:3]`, asserts $\text{Valid} = 1$, and serves the data.

---

## 4. Two-Way Set-Associative Cache Architecture

To alleviate conflict misses caused by two frequently accessed addresses mapping to the same index, the 2-way set-associative cache allows an address to reside in either of two locations within a set (`Way 0` or `Way 1`).

### 4.1 Internal Storage Elements
The cache is organized into 4 sets. Each set contains two ways plus a 1-bit LRU status register:
- **Way 0:** Valid (1 bit), Tag (6 bits), Data (8 bits)
- **Way 1:** Valid (1 bit), Tag (6 bits), Data (8 bits)
- **LRU Bit:** 1 bit per set (tracks recency of access between Way 0 and Way 1)

```
       ================================ WAY 0 ================================   ================================ WAY 1 ================================
Set    Valid   Tag [5:0]    Data [7:0]                                           Valid   Tag [5:0]    Data [7:0]                                   LRU
 0      [ ]     [      ]     [        ]                                           [ ]     [      ]     [        ]                                  [ ]
 1      [ ]     [      ]     [        ]                                           [ ]     [      ]     [        ]                                  [ ]
 2      [ ]     [      ]     [        ]                                           [ ]     [      ]     [        ]                                  [ ]
 3      [ ]     [      ]     [        ]                                           [ ]     [      ]     [        ]                                  [ ]
```

### 4.2 Hit and Miss Determination
1. The 2-bit set index `address[1:0]` simultaneously accesses both Way 0 and Way 1 of the designated set.
2. Two parallel 6-bit comparators compare `address[7:2]` against the stored tags:
   $$\text{Hit\_Way0} = \text{Valid0}[\text{set}] \land (\text{Tag0}[\text{set}] == \text{address}[7:2])$$
   $$\text{Hit\_Way1} = \text{Valid1}[\text{set}] \land (\text{Tag1}[\text{set}] == \text{address}[7:2])$$
3. Overall **Cache Hit**:
   $$\text{Cache\_Hit} = \text{Hit\_Way0} \lor \text{Hit\_Way1}$$
4. If a hit occurs:
   - If $\text{Hit\_Way0}$, `Data0` is forwarded to the processor.
   - If $\text{Hit\_Way1}$, `Data1` is forwarded to the processor.
   - The set's LRU bit is updated to record the most recently used way.
5. If neither way hits, a **Cache Miss** is flagged.

---

## 5. Least Recently Used (LRU) Replacement Logic

When a cache miss occurs in the 2-way set-associative cache and both ways are currently occupied ($\text{Valid0} = 1$ and $\text{Valid1} = 1$), one line must be evicted to make room for the new block. The project uses a **1-bit LRU policy per set**.

### 5.1 Bit Definition Convention
For each set $i \in \{0, 1, 2, 3\}$, let $\text{LRU}[i]$ represent recency:
- $\text{LRU}[i] = 0$: Way 0 was accessed more recently; **Way 1 is the LRU victim**.
- $\text{LRU}[i] = 1$: Way 1 was accessed more recently; **Way 0 is the LRU victim**.

### 5.2 LRU Update Rules
- **Access to Way 0 (Read/Write Hit or Allocation to Way 0):**  
  $\text{LRU}[i] \leftarrow 0$ (marks Way 0 as most recently used; Way 1 becomes the next eviction candidate).
- **Access to Way 1 (Read/Write Hit or Allocation to Way 1):**  
  $\text{LRU}[i] \leftarrow 1$ (marks Way 1 as most recently used; Way 0 becomes the next eviction candidate).

### 5.3 Eviction & Replacement Selection
On a cache miss at set $i$:
1. If $\text{Valid0}[i] == 0$, allocate into **Way 0** (no eviction required).
2. Else if $\text{Valid1}[i] == 0$, allocate into **Way 1** (no eviction required).
3. If both ways are valid ($\text{Valid0} == 1 \land \text{Valid1} == 1$):
   - If $\text{LRU}[i] == 0$, replace **Way 1**.
   - If $\text{LRU}[i] == 1$, replace **Way 0**.
4. Update the tag and data of the chosen victim line, set its valid bit to 1, and update $\text{LRU}[i]$ accordingly.

---

## 6. Main Memory Interaction & Controller FSM

Main memory is modeled as a 256-entry array of 8-bit registers (`[7:0] memory [0:255]`).

### 6.1 Planned Controller States
The cache controller will be orchestrated by a synchronous Finite State Machine (FSM):

```
       +---------------------------------------------+
       |                    IDLE                     |
       +---------------------------------------------+
                              |
                              | CPU request (rd_en / wr_en)
                              v
       +---------------------------------------------+
       |                COMPARE_TAG                  |
       +---------------------------------------------+
             |                                 |
             | Hit                             | Miss
             v                                 v
       +---------------+             +-----------------------+
       |  SERVE_DATA   |             |   MEM_FETCH_WAIT      |
       +---------------+             +-----------------------+
             |                                 |
             | Complete                        | Memory ready
             v                                 v
           (IDLE)                    +-----------------------+
                                     |   UPDATE_CACHE_LINE   |
                                     +-----------------------+
                                               |
                                               v
                                            (IDLE)
```

1. **IDLE:** Controller waits for CPU read or write requests.
2. **COMPARE_TAG:** Reads the indexed cache line(s) and compares tag bits.
3. **SERVE_DATA:** On hit, multiplexes cached data to `cpu_rdata` and asserts `ready` in the same or next cycle.
4. **MEM_FETCH_WAIT:** On miss, drives `mem_addr` onto the memory bus, asserts `mem_rd_en`, and waits for memory response latency.
5. **UPDATE_CACHE_LINE:** Writes incoming memory byte into the selected way/line, updates valid and tag registers, updates LRU bit, and completes the request.

---

## 7. Comparative Performance Metrics (Planned)

During the verification phase, both caches will be subjected to identical synthetic address streams to measure:
- **Hit Count & Miss Count:** Total occurrences of hits vs. misses.
- **Hit Ratio:** $\frac{\text{Hits}}{\text{Hits} + \text{Misses}} \times 100\%$
- **Conflict Miss Reduction:** Demonstrating scenarios where alternating addresses mapping to the same index cause continuous thrashing in the direct-mapped cache, but hit reliably in the 2-way cache.
- **Access Latency:** Total cycle count to execute benchmark traces.


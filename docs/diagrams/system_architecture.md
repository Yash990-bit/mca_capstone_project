# System Architecture & Flow Diagrams

This document contains Mermaid diagrams illustrating the top-level architecture, cache internal structures, and control flow.

---

## 1. Complete System Architecture

```mermaid
flowchart TD
    subgraph Host ["CPU / Testbench Master"]
        CPU[Processor Core / Pattern Generator]
    end

    subgraph CacheSystem ["Cache Subsystem (Interchangeable)"]
        direction TB
        subgraph DirectMapped ["Direct-Mapped Option (Shivam)"]
            DM_Index["Line Index Decoder (3 bits)"]
            DM_TagArray["Tag Array (8 x 5-bit)"]
            DM_DataArray["Data Array (8 x 8-bit)"]
            DM_Comp["Tag Comparator (5-bit)"]
        end

        subgraph TwoWayAssoc ["2-Way Set-Associative Option (Keshav + Shitanshu)"]
            TW_Index["Set Index Decoder (2 bits)"]
            Way0["Way 0: Valid, Tag (6-bit), Data (8-bit)"]
            Way1["Way 1: Valid, Tag (6-bit), Data (8-bit)"]
            DualComp["Dual Tag Comparators"]
            LRU_Unit["1-Bit LRU Unit (4 sets)"]
        end

        FSM["Cache Controller FSM"]
    end

    subgraph Memory ["Backing Main Memory"]
        RAM["256 x 8-bit Synchronous RAM"]
    end

    CPU -->|"req_addr[7:0], req_wdata[7:0], req_wr_en, req_valid"| CacheSystem
    CacheSystem -->|"resp_rdata[7:0], resp_valid, cache_hit, busy"| CPU

    CacheSystem -->|"mem_addr[7:0], mem_wdata[7:0], mem_wr_en, mem_req"| Memory
    Memory -->|"mem_rdata[7:0], mem_ready"| CacheSystem
```

---

## 2. Two-Way Set-Associative Cache Internal Organization

```mermaid
flowchart LR
    Addr["CPU Address [7:0]"]
    Tag["Tag [7:2] (6 bits)"]
    Set["Set Index [1:0] (2 bits)"]

    Addr --> Tag
    Addr --> Set

    Set --> Way0_Array["Way 0 Array<br/>(4 x [V, 6-bit Tag, 8-bit Data])"]
    Set --> Way1_Array["Way 1 Array<br/>(4 x [V, 6-bit Tag, 8-bit Data])"]
    Set --> LRU_Array["LRU Bits<br/>(4 x 1-bit)"]

    Way0_Array --> Comp0["Comparator 0"]
    Tag --> Comp0
    Way1_Array --> Comp1["Comparator 1"]
    Tag --> Comp1

    Comp0 --> Hit0["Hit Way 0"]
    Comp1 --> Hit1["Hit Way 1"]

    Hit0 --> HitLogic["Cache Hit Logic"]
    Hit1 --> HitLogic
    HitLogic --> CacheHit["cache_hit = Hit0 OR Hit1"]

    Hit0 --> Mux["Data Mux"]
    Hit1 --> Mux
    Way0_Array --> Mux
    Way1_Array --> Mux
    Mux --> RData["resp_rdata [7:0]"]

    HitLogic --> LRU_Update["LRU Update Logic"]
    LRU_Array --> VictimSel["Victim Selection (on Miss)"]
```

---

## 3. Cache Controller Finite State Machine (FSM)

```mermaid
stateDiagram-v2
    [*] --> IDLE

    IDLE --> LOOKUP : req_valid == 1
    LOOKUP --> HIT_SERVICE : cache_hit == 1
    LOOKUP --> MISS_ALLOCATE : cache_hit == 0 (Read Miss)
    LOOKUP --> WRITE_THROUGH : req_wr_en == 1 (Write)

    HIT_SERVICE --> IDLE : resp_valid asserted (1 cycle)

    MISS_ALLOCATE --> MEM_WAIT : mem_req = 1, mem_wr_en = 0
    MEM_WAIT --> REFILL : mem_ready == 1
    REFILL --> IDLE : Line refilled, LRU updated, resp_valid asserted

    WRITE_THROUGH --> MEM_WAIT_WR : mem_req = 1, mem_wr_en = 1
    MEM_WAIT_WR --> IDLE : mem_ready == 1, resp_valid asserted
```

---

## 4. LRU Replacement Logic Flow

```mermaid
flowchart TD
    Miss["Cache Read Miss Occurs"] --> CheckValid{"Is any way in the<br/>set Invalid (V=0)?"}
    
    CheckValid -->|"Way 0 is Invalid"| AllocWay0["Allocate into Way 0<br/>Set V0=1, Tag0=Tag, Data0=MemData"]
    CheckValid -->|"Way 1 is Invalid"| AllocWay1["Allocate into Way 1<br/>Set V1=1, Tag1=Tag, Data1=MemData"]
    CheckValid -->|"Both Ways Valid"| CheckLRU{"Check LRU[set_index]"}

    CheckLRU -->|"LRU == 0 (Way 0 MRU)"| VictimWay1["Evict Way 1 (Victim)<br/>Overwrite Way 1 with new data"]
    CheckLRU -->|"LRU == 1 (Way 1 MRU)"| VictimWay0["Evict Way 0 (Victim)<br/>Overwrite Way 0 with new data"]

    AllocWay0 --> UpdateLRU0["Update LRU[set_index] = 0<br/>(Way 0 is now MRU)"]
    AllocWay1 --> UpdateLRU1["Update LRU[set_index] = 1<br/>(Way 1 is now MRU)"]
    VictimWay1 --> UpdateLRU1
    VictimWay0 --> UpdateLRU0
```

# Address Mapping & Capacity Equivalence

This document illustrates the address bit partitioning for both cache configurations and explains why their capacities are strictly equal.

---

## 1. Bit Allocation Diagrams

### 1.1 Two-Way Set-Associative Cache (4 Sets × 2 Ways)

```
Bit:      [7]    [6]    [5]    [4]    [3]    [2]    [1]    [0]
Field:    |---------------- Tag ----------------| |-- Set --|
Width:                 6 bits                         2 bits
Range:              address[7:2]                   address[1:0]
```

- **Set Index (`address[1:0]`):** 2 bits select 1 of 4 sets ($2^2 = 4$).
- **Tag (`address[7:2]`):** 6 bits identify the unique memory block mapped into that set.
- **Offset:** 0 bits, because each cache block is 1 byte ($2^0 = 1$).

---

### 1.2 Direct-Mapped Cache (8 Lines)

```
Bit:      [7]    [6]    [5]    [4]    [3]    [2]    [1]    [0]
Field:    |----------- Tag -----------| |------- Line Index -------|
Width:                 5 bits                         3 bits
Range:              address[7:3]                   address[2:0]
```

- **Line Index (`address[2:0]`):** 3 bits select 1 of 8 lines ($2^3 = 8$).
- **Tag (`address[7:3]`):** 5 bits identify the memory block mapped into that line.
- **Offset:** 0 bits, because each cache block is 1 byte ($2^0 = 1$).

---

## 2. Why Both Caches Have Equal Capacity

A common point of confusion is whether the different number of sets implies different cache sizes. They are identical:

$$\text{Capacity}_{\text{Direct-Mapped}} = 8 \text{ lines} \times 1 \text{ byte/line} = 8 \text{ bytes}$$

$$\text{Capacity}_{\text{2-Way Set-Associative}} = 4 \text{ sets} \times 2 \text{ ways/set} \times 1 \text{ byte/block} = 8 \text{ bytes}$$

| Metric | Direct-Mapped Cache | 2-Way Set-Associative Cache |
|:---|:---:|:---:|
| Total Data Capacity | 8 bytes | 8 bytes |
| Number of Sets | 8 sets (1 line/set) | 4 sets (2 lines/set) |
| Total Cache Lines | 8 lines | 8 lines |
| Block Size | 1 byte | 1 byte |
| Tag Bits per Line | 5 bits | 6 bits |
| Valid Bits per Line | 1 bit | 1 bit |
| Total Tag Storage | $8 \times 5 = 40 \text{ bits}$ | $8 \times 6 = 48 \text{ bits}$ |
| Replacement State | 0 bits (no choice) | 4 bits (1 bit/set × 4 sets) |

> **Key Architectural Insight:** The 2-Way cache stores 8 additional tag bits and 4 replacement bits compared to the direct-mapped cache. This small hardware overhead enables the elimination of severe conflict misses.

---

## 3. Concrete Address Mapping Examples

Consider the following three addresses:
- **Address A:** `0x00` = `8'b0000_0000`
- **Address B:** `0x10` = `8'b0001_0000`
- **Address C:** `0x20` = `8'b0010_0000`

### Mapping in Direct-Mapped Cache:
- `0x00`: Tag = `00000` (`0x00`), Line Index = `000` (`0`).
- `0x10`: Tag = `00010` (`0x02`), Line Index = `000` (`0`).
- `0x20`: Tag = `00100` (`0x04`), Line Index = `000` (`0`).

*Observation:* All three addresses map to **Line 0**. In the direct-mapped cache, accessing `0x00`, `0x10`, `0x00`, `0x10` creates 100% conflict misses (thrashing).

### Mapping in 2-Way Set-Associative Cache:
- `0x00`: Tag = `000000` (`0x00`), Set Index = `00` (`0`).
- `0x10`: Tag = `000100` (`0x04`), Set Index = `00` (`0`).
- `0x20`: Tag = `001000` (`0x08`), Set Index = `00` (`0`).

*Observation:* All three map to **Set 0**. However, Set 0 has two ways:
1. `0x00` is placed in Way 0.
2. `0x10` is placed in Way 1.
3. Accessing `0x00` and `0x10` repeatedly produces **100% cache hits** in the 2-way cache!
4. When `0x20` is subsequently accessed, LRU selects the least recently used of the two to replace.

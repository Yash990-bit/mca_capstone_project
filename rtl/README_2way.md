# Two-way cache module

`cache_2way` is a synthesizable Verilog-2001 cache with four sets, two ways per
set, one byte per line, and an 8-bit address/data path. It uses `address[7:2]`
as the tag and `address[1:0]` as the set index. The cache compares both tags in
parallel, selects the matching way's data on a hit, and refills a line after a
read miss.

The ports follow the agreed contract in `docs/INTERFACE_SPECIFICATION.md`:

- CPU: `clk`, active-low asynchronous `rst_n`, `req_valid`, `req_addr`,
  `req_wr_en`, `req_wdata`, `resp_rdata`, `resp_valid`, `cache_hit`, `busy`.
- Memory: `mem_req`, `mem_wr_en`, `mem_addr`, `mem_wdata`, `mem_rdata`,
  `mem_ready`.

Writes use write-through/no-write-allocate. A write hit updates the cache and
backing memory; a write miss goes to memory without allocating a line. Reset
clears all valid bits. The module instantiates the agreed `lru_controller`
interface from `rtl/lru_controller.v`; when both ways in a set are valid, that
module selects the replacement way. Invalid ways are chosen first.

Run the standalone unit test with `make sim_2way`. Its source is
`tb/tb_cache_2way_keshav.v`, separate from Kaavya's `tb/tb_2way.v`; the run log
is written to `results/sim_2way_keshav.log`.

## Integration note

At this commit, `rtl/lru_controller.v` is still the repository's placeholder
skeleton. The cache wiring uses its documented ports, but full-set replacement
cannot be verified until Shitanshu supplies the implementation. The test covers
cold fills into both ways, both way hits, data selection, write hit, and reset
invalidation; it does not claim to verify a full-set LRU eviction.

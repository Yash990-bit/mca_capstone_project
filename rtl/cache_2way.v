// =============================================================================
// Module: cache_2way
// Project: 2-Way Set-Associative Cache with LRU Replacement
// Assigned Member: Keshav (Member 2)
// Status: PLACEHOLDER SKELETON (To be implemented by Keshav)
// Specification: docs/INTERFACE_SPECIFICATION.md & docs/ARCHITECTURE.md
// =============================================================================

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
    // Backing Memory Interface
    output wire       mem_req,
    output wire       mem_wr_en,
    output wire [7:0] mem_addr,
    output wire [7:0] mem_wdata,
    input  wire [7:0] mem_rdata,
    input  wire       mem_ready
);

    // =========================================================================
    // TODO: KESHAV TO IMPLEMENT:
    // 1. Way 0 and Way 1 data arrays (4 x 8-bit each)
    // 2. Way 0 and Way 1 tag arrays (4 x 6-bit each)
    // 3. Valid bit arrays (4 x 1-bit each)
    // 4. Parallel tag comparators against req_addr[7:2]
    // 5. Way selection and hit detection
    // 6. Submodule instantiation / integration with Shitanshu's LRU controller
    // =========================================================================

endmodule

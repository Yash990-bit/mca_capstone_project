// =============================================================================
// Module: cache_direct
// Project: Direct-Mapped Cache Baseline
// Assigned Member: Shivam (Member 4)
// Status: PLACEHOLDER SKELETON (To be implemented by Shivam)
// Specification: docs/INTERFACE_SPECIFICATION.md & docs/ARCHITECTURE.md
// =============================================================================

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

    // =========================================================================
    // TODO: SHIVAM TO IMPLEMENT:
    // 1. 8-line direct-mapped data array (8 x 8-bit)
    // 2. 8-line tag array (8 x 5-bit)
    // 3. 8-line valid bit array (8 x 1-bit)
    // 4. Line index extraction using req_addr[2:0]
    // 5. 5-bit tag comparator against req_addr[7:3]
    // 6. Hit/miss detection and read-data forwarding
    // 7. Write-through / no-write-allocate memory logic
    // =========================================================================

endmodule

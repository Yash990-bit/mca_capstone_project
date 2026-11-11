// =============================================================================
// Module: top_module
// Project: Top-Level Integration Wrapper (Direct-Mapped vs 2-Way Cache)
// Assigned Member: Yash (Project Lead / Integration)
// Status: INTEGRATION PLACEHOLDER (To be integrated in Phase 2/3)
// Specification: docs/INTERFACE_SPECIFICATION.md & docs/ARCHITECTURE.md
// =============================================================================

module top_module (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       sel_2way_cache, // 1 = 2-Way Cache, 0 = Direct-Mapped Cache
    // CPU Interface
    input  wire       req_valid,
    input  wire [7:0] req_addr,
    input  wire       req_wr_en,
    input  wire [7:0] req_wdata,
    output wire [7:0] resp_rdata,
    output wire       resp_valid,
    output wire       cache_hit,
    output wire       busy
);

    // =========================================================================
    // TO BE COMPLETED DURING INTEGRATION PHASE:
    // Instantiates cache_2way, cache_direct, and main_mem behavioral model.
    // =========================================================================

endmodule

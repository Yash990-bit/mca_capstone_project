// =============================================================================
// Module: cache_fsm
// Project: Cache Controller Finite State Machine
// Assigned Member: Shitanshu (Member 3)
// Status: PLACEHOLDER SKELETON (To be implemented by Shitanshu)
// Specification: docs/INTERFACE_SPECIFICATION.md & docs/ARCHITECTURE.md
// =============================================================================

module cache_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       req_valid,
    input  wire       req_wr_en,
    input  wire       cache_hit,
    input  wire       mem_ready,
    output wire       mem_req,
    output wire       mem_wr_en,
    output wire       resp_valid,
    output wire       busy,
    output wire       refill_en,
    output wire [2:0] current_state
);

    // =========================================================================
    // TO BE IMPLEMENTED BY SHITANSHU:
    // - Controller states: IDLE, LOOKUP, HIT_SERVICE, MEM_WAIT, REFILL
    // - Memory transaction handshake
    // - CPU response and stall generation
    // =========================================================================

endmodule

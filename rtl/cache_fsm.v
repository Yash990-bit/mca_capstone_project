// =============================================================================
// Module: cache_fsm
// Project: Design and Performance Analysis of a 2-Way Set-Associative Cache
//          with LRU Replacement Compared with a Direct-Mapped Cache
// Component: Cache Controller Finite State Machine (FSM)
// Language: Verilog-2001 (Synthesizable RTL)
// Reference: docs/INTERFACE_SPECIFICATION.md & docs/ARCHITECTURE.md
// =============================================================================
//
// STATE OVERVIEW:
//   IDLE         (3'b000) : Ready to accept a new CPU request (busy = 0).
//   LOOKUP       (3'b001) : Evaluates hit/miss and routes read/write path.
//   HIT_RESPONSE (3'b010) : Returns cached read data (resp_valid = 1).
//   MEMORY_WAIT  (3'b011) : Asserts mem_req and waits for mem_ready == 1.
//   REFILL       (3'b100) : Enables cache line & LRU update (refill_en = 1).
//   RESPONSE     (3'b101) : Completes memory-backed transaction (resp_valid = 1).
// =============================================================================

`timescale 1ns / 1ps

module cache_fsm (
    input  wire       clk,           // System clock (rising-edge active)
    input  wire       rst_n,         // Asynchronous active-low reset
    input  wire       req_valid,     // CPU request valid
    input  wire       req_wr_en,     // 1 = Write, 0 = Read
    input  wire       cache_hit,     // Hit indicator from tag comparators
    input  wire       mem_ready,     // Backing memory transaction complete
    output reg        mem_req,       // Request to backing memory
    output reg        mem_wr_en,     // Memory write enable (1 = Write, 0 = Read)
    output reg        resp_valid,    // Asserted when transaction completes
    output wire       busy,          // High while FSM is servicing a request
    output reg        refill_en,     // High in REFILL state to update cache/LRU
    output wire [2:0] current_state  // Current FSM state for debug/waveforms
);

    // State encoding (3-bit binary)
    localparam [2:0] STATE_IDLE         = 3'b000;
    localparam [2:0] STATE_LOOKUP       = 3'b001;
    localparam [2:0] STATE_HIT_RESPONSE = 3'b010;
    localparam [2:0] STATE_MEMORY_WAIT  = 3'b011;
    localparam [2:0] STATE_REFILL       = 3'b100;
    localparam [2:0] STATE_RESPONSE     = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;
    reg       latched_wr_en; // Latches req_wr_en when request is accepted

    // -------------------------------------------------------------------------
    // 1. Sequential State Register & Request Direction Latch
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= STATE_IDLE;
            latched_wr_en <= 1'b0;
        end else begin
            state <= next_state;
            if (state == STATE_IDLE && req_valid) begin
                latched_wr_en <= req_wr_en;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. Combinational Next-State Logic (No Latches)
    // -------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: begin
                if (req_valid)
                    next_state = STATE_LOOKUP;
            end

            STATE_LOOKUP: begin
                if (!latched_wr_en && cache_hit)
                    next_state = STATE_HIT_RESPONSE;
                else
                    next_state = STATE_MEMORY_WAIT;
            end

            STATE_HIT_RESPONSE: begin
                next_state = STATE_IDLE;
            end

            STATE_MEMORY_WAIT: begin
                if (mem_ready) begin
                    if (!latched_wr_en)
                        next_state = STATE_REFILL;
                    else
                        next_state = STATE_RESPONSE;
                end
            end

            STATE_REFILL: begin
                next_state = STATE_RESPONSE;
            end

            STATE_RESPONSE: begin
                next_state = STATE_IDLE;
            end

            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // 3. Combinational Output Logic (Moore-style, glitch-free defaults)
    // -------------------------------------------------------------------------
    always @(*) begin
        mem_req    = 1'b0;
        mem_wr_en  = 1'b0;
        resp_valid = 1'b0;
        refill_en  = 1'b0;

        case (state)
            STATE_HIT_RESPONSE: begin
                resp_valid = 1'b1;
            end

            STATE_MEMORY_WAIT: begin
                mem_req   = 1'b1;
                mem_wr_en = latched_wr_en;
            end

            STATE_REFILL: begin
                refill_en = 1'b1;
            end

            STATE_RESPONSE: begin
                resp_valid = 1'b1;
            end

            default: begin
                // All outputs remain 0 in IDLE and LOOKUP
            end
        endcase
    end

    // Busy whenever FSM is outside IDLE (prevents overlapping requests)
    assign busy          = (state != STATE_IDLE);
    assign current_state = state;

endmodule

// =============================================================================
// Module: cache_direct
// Project: Design and Performance Analysis of a 2-Way Set-Associative Cache
//          with LRU Replacement Compared with a Direct-Mapped Cache
// Component: Direct-Mapped Cache Baseline Architecture
// Assigned Member: Shivam (RTL Engineer - Direct-Mapped Cache)
// Language: Verilog-2001 (Synthesizable RTL)
// Reference: docs/INTERFACE_SPECIFICATION.md & docs/ARCHITECTURE.md
// =============================================================================
//
// ARCHITECTURAL OVERVIEW:
// -----------------------
// Total Capacity   : 8 Bytes
// Number of Lines  : 8 Lines (1 byte per line)
// Block/Line Size  : 1 Byte (Offset = 0 bits)
// Address Width    : 8 bits [7:0]
//   - Tag Field    : req_addr[7:3] (5 bits)
//   - Line Index   : req_addr[2:0] (3 bits, selects 1 of 8 lines)
// Data Width       : 8 bits [7:0]
//
// WRITE POLICY:
// -------------
// Write-Through with No-Write-Allocate
// - Write Hit : Update internal line data and write through to backing memory.
// - Write Miss: Bypasses cache directly to backing memory (line NOT allocated).
//
// REPLACEMENT POLICY:
// -------------------
// Direct Mapping (Direct eviction on conflict miss without associativity).
// =============================================================================

`timescale 1ns / 1ps

module cache_direct (
    input  wire       clk,        // System Clock (Rising edge active)
    input  wire       rst_n,      // Asynchronous Active-Low System Reset

    // -------------------------------------------------------------------------
    // CPU / Master Interface
    // -------------------------------------------------------------------------
    input  wire       req_valid,  // Asserted by CPU when requesting transaction
    input  wire [7:0] req_addr,   // 8-bit memory target byte address
    input  wire       req_wr_en,  // 1 = Write transaction, 0 = Read transaction
    input  wire [7:0] req_wdata,  // 8-bit write data word
    output wire [7:0] resp_rdata, // 8-bit data returned to CPU on read
    output wire       resp_valid, // Asserted high when transaction completes
    output wire       cache_hit,  // High on cache hit, low on cache miss
    output wire       busy,       // High while servicing memory stall/fetch

    // -------------------------------------------------------------------------
    // Backing Memory Interface (256 x 8-bit synchronous RAM)
    // -------------------------------------------------------------------------
    output wire       mem_req,    // Asserted to request backing memory access
    output wire       mem_wr_en,  // 1 = Memory write, 0 = Memory read
    output wire [7:0] mem_addr,   // 8-bit address sent to backing memory
    output wire [7:0] mem_wdata,  // 8-bit data sent to backing memory
    input  wire [7:0] mem_rdata,  // 8-bit data returned from backing memory
    input  wire       mem_ready   // Asserted by backing memory when complete
);

    // =========================================================================
    // FSM State Encoding
    // =========================================================================
    localparam [1:0] STATE_IDLE       = 2'b00; // Ready for CPU request / Read hit
    localparam [1:0] STATE_READ_WAIT  = 2'b01; // Waiting for memory read response
    localparam [1:0] STATE_WRITE_WAIT = 2'b10; // Waiting for memory write response

    reg [1:0] state;

    // =========================================================================
    // Cache Storage Arrays (8 lines total)
    // =========================================================================
    // Line Index: 3 bits [2:0] -> 8 entries
    // Data Field: 8 bits [7:0]
    // Tag Field : 5 bits [4:0] -> address[7:3]
    // Valid Bit : 1 bit
    // =========================================================================
    reg [7:0] data_array  [0:7];
    reg [4:0] tag_array   [0:7];
    reg       valid_array [0:7];

    // =========================================================================
    // Request Latching Registers (for multi-cycle memory transactions)
    // =========================================================================
    reg [7:0] latched_addr;
    reg [7:0] latched_wdata;
    reg       latched_hit;

    // Loop iterator for reset initialization
    integer i;

    // =========================================================================
    // Address Bit Decomposition (Direct-Mapped)
    // =========================================================================
    // address[7:3] -> 5-bit Tag
    // address[2:0] -> 3-bit Line Index
    // =========================================================================
    wire [2:0] current_index = req_addr[2:0];
    wire [4:0] current_tag   = req_addr[7:3];

    // Combinational Tag Comparator & Valid Check
    wire hit_comb = valid_array[current_index] && (tag_array[current_index] == current_tag);

    // =========================================================================
    // Output Combinational Logic (Single-cycle Read Hit & Handshake Protocol)
    // =========================================================================

    // resp_valid: Asserted on read hit in IDLE, or when memory completes in WAIT states
    assign resp_valid = (state == STATE_IDLE && req_valid && !req_wr_en && hit_comb) ||
                        (state == STATE_READ_WAIT  && mem_ready) ||
                        (state == STATE_WRITE_WAIT && mem_ready);

    // resp_rdata: Forward cached data on hit, memory data on read refill, 0 otherwise
    assign resp_rdata = (state == STATE_IDLE && req_valid && !req_wr_en && hit_comb) ? data_array[current_index] :
                        (state == STATE_READ_WAIT && mem_ready)                       ? mem_rdata :
                        8'h00;

    // cache_hit: Reports hit/miss status for current or completing transaction
    assign cache_hit = (state == STATE_IDLE && req_valid) ? hit_comb :
                       (state == STATE_WRITE_WAIT)        ? latched_hit :
                       1'b0;

    // busy: Stalls CPU during misses or writes waiting for backing memory
    assign busy = (state == STATE_READ_WAIT  && !mem_ready) ||
                  (state == STATE_WRITE_WAIT && !mem_ready) ||
                  (state == STATE_IDLE && req_valid && (req_wr_en || !hit_comb));

    // =========================================================================
    // Backing Memory Bus Driving Logic
    // =========================================================================
    assign mem_req = (state == STATE_READ_WAIT) ||
                     (state == STATE_WRITE_WAIT) ||
                     (state == STATE_IDLE && req_valid && (req_wr_en || !hit_comb));

    assign mem_wr_en = (state == STATE_IDLE) ? req_wr_en : (state == STATE_WRITE_WAIT);

    assign mem_addr = (state == STATE_IDLE) ? req_addr : latched_addr;

    assign mem_wdata = (state == STATE_IDLE) ? req_wdata : latched_wdata;

    // =========================================================================
    // Synchronous FSM & Array Update Logic
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // -----------------------------------------------------------------
            // Asynchronous Reset: Invalidate all cache lines and reset state
            // -----------------------------------------------------------------
            state         <= STATE_IDLE;
            latched_addr  <= 8'h00;
            latched_wdata <= 8'h00;
            latched_hit   <= 1'b0;

            for (i = 0; i < 8; i = i + 1) begin
                valid_array[i] <= 1'b0;
                tag_array[i]   <= 5'b00000;
                data_array[i]  <= 8'h00;
            end
        end else begin
            case (state)
                // -------------------------------------------------------------
                // STATE_IDLE: Awaiting CPU request
                // -------------------------------------------------------------
                STATE_IDLE: begin
                    if (req_valid) begin
                        if (!req_wr_en) begin
                            // --- READ OPERATION ---
                            if (hit_comb) begin
                                // Read Hit: Completed combinationally in 1 cycle!
                                // Cache stays in STATE_IDLE; no memory access.
                                state <= STATE_IDLE;
                            end else begin
                                // Read Miss: Latch address, initiate memory fetch
                                latched_addr <= req_addr;
                                latched_hit  <= 1'b0;
                                state        <= STATE_READ_WAIT;
                            end
                        end else begin
                            // --- WRITE OPERATION (Write-Through) ---
                            latched_addr  <= req_addr;
                            latched_wdata <= req_wdata;
                            latched_hit   <= hit_comb;

                            if (hit_comb) begin
                                // Write Hit: Update cache line data immediately
                                data_array[current_index] <= req_wdata;
                            end
                            // Write Miss: No-Write-Allocate (cache line is NOT allocated)

                            state <= STATE_WRITE_WAIT;
                        end
                    end
                end

                // -------------------------------------------------------------
                // STATE_READ_WAIT: Stalling CPU until memory returns requested byte
                // -------------------------------------------------------------
                STATE_READ_WAIT: begin
                    if (mem_ready) begin
                        // Backing memory returned data byte: Refill direct-mapped line
                        data_array[latched_addr[2:0]]  <= mem_rdata;
                        tag_array[latched_addr[2:0]]   <= latched_addr[7:3];
                        valid_array[latched_addr[2:0]] <= 1'b1;

                        // Transaction finishes, return to IDLE
                        state <= STATE_IDLE;
                    end
                end

                // -------------------------------------------------------------
                // STATE_WRITE_WAIT: Waiting for backing memory write acknowledge
                // -------------------------------------------------------------
                STATE_WRITE_WAIT: begin
                    if (mem_ready) begin
                        // Write completed in backing memory
                        state <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule

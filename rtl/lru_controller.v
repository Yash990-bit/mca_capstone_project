// =============================================================================
// Module: lru_controller
// Project: Design and Performance Analysis of a 2-Way Set-Associative Cache
//          with LRU Replacement Compared with a Direct-Mapped Cache
// Component: 1-Bit Per-Set LRU Replacement Controller (4 Sets x 2 Ways)
// Language: Verilog-2001 (Synthesizable RTL)
// Reference: docs/INTERFACE_SPECIFICATION.md & docs/ARCHITECTURE.md
// =============================================================================
//
// LRU CONVENTION:
//   lru_bits[set] == 1'b0 -> Way 0 is Least Recently Used (victim = Way 0)
//   lru_bits[set] == 1'b1 -> Way 1 is Least Recently Used (victim = Way 1)
//
// UPDATE RULES (on positive clock edge when access_valid == 1):
//   - If Way 0 is accessed (access_way == 1'b0), mark Way 1 as LRU (1'b1).
//   - If Way 1 is accessed (access_way == 1'b1), mark Way 0 as LRU (1'b0).
//
// VICTIM SELECTION RULES (combinational):
//   1. Prefer an invalid way first:
//      - If way0_valid == 0 -> victim_way = 1'b0
//      - Else if way1_valid == 0 -> victim_way = 1'b1
//   2. If both ways are valid -> victim_way = lru_bits[set_index]
// =============================================================================

`timescale 1ns / 1ps

module lru_controller (
    input  wire       clk,            // System clock (rising-edge active)
    input  wire       rst_n,          // Asynchronous active-low reset
    input  wire [1:0] set_index,      // 2-bit set index (selects 1 of 4 sets)
    input  wire       access_valid,   // High when a cache hit or refill occurs
    input  wire       access_way,     // 0 = Way 0 accessed, 1 = Way 1 accessed
    input  wire       way0_valid,     // Valid bit of Way 0 in selected set
    input  wire       way1_valid,     // Valid bit of Way 1 in selected set
    output wire       victim_way,     // 0 = Evict/Fill Way 0, 1 = Evict/Fill Way 1
    output wire [3:0] lru_state_all   // Debug/waveform visibility for all 4 sets
);

    // 1-bit LRU register per set (4 sets total)
    reg [3:0] lru_bits;

    // -------------------------------------------------------------------------
    // Sequential LRU State Storage & Update
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // On reset, initialize all sets to 0 (Way 0 is default LRU)
            lru_bits <= 4'b0000;
        end else if (access_valid) begin
            // Mark the OTHER way as Least Recently Used
            // access_way == 0 -> Way 1 becomes LRU (1'b1)
            // access_way == 1 -> Way 0 becomes LRU (1'b0)
            lru_bits[set_index] <= ~access_way;
        end
    end

    // -------------------------------------------------------------------------
    // Combinational Victim Selection (Invalid-Way Preference First)
    // -------------------------------------------------------------------------
    assign victim_way = (!way0_valid) ? 1'b0 :
                        (!way1_valid) ? 1'b1 :
                                        lru_bits[set_index];

    // Expose all 4 set LRU bits for verification and waveform inspection
    assign lru_state_all = lru_bits;

endmodule

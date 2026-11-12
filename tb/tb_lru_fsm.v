// =============================================================================
// Testbench: tb_lru_fsm
// Project: 2-Way Set-Associative Cache with LRU Replacement
// Purpose: Unit & Scenario Verification for rtl/lru_controller.v & rtl/cache_fsm.v
// Language: Verilog-2001
// =============================================================================

`timescale 1ns / 1ps

module tb_lru_fsm;

    // -------------------------------------------------------------------------
    // Signals for lru_controller
    // -------------------------------------------------------------------------
    reg        clk;
    reg        rst_n;
    reg  [1:0] set_index;
    reg        access_valid;
    reg        access_way;
    reg        way0_valid;
    reg        way1_valid;
    wire       victim_way;
    wire [3:0] lru_state_all;

    // -------------------------------------------------------------------------
    // Signals for cache_fsm
    // -------------------------------------------------------------------------
    reg        fsm_req_valid;
    reg        fsm_req_wr_en;
    reg        fsm_cache_hit;
    reg        fsm_mem_ready;
    wire       fsm_mem_req;
    wire       fsm_mem_wr_en;
    wire       fsm_resp_valid;
    wire       fsm_busy;
    wire       fsm_refill_en;
    wire [2:0] fsm_state;

    // Counters
    integer total_tests;
    integer passed_tests;
    integer failed_tests;

    // -------------------------------------------------------------------------
    // Instantiate DUTs
    // -------------------------------------------------------------------------
    lru_controller dut_lru (
        .clk           (clk),
        .rst_n         (rst_n),
        .set_index     (set_index),
        .access_valid  (access_valid),
        .access_way    (access_way),
        .way0_valid    (way0_valid),
        .way1_valid    (way1_valid),
        .victim_way    (victim_way),
        .lru_state_all (lru_state_all)
    );

    cache_fsm dut_fsm (
        .clk           (clk),
        .rst_n         (rst_n),
        .req_valid     (fsm_req_valid),
        .req_wr_en     (fsm_req_wr_en),
        .cache_hit     (fsm_cache_hit),
        .mem_ready     (fsm_mem_ready),
        .mem_req       (fsm_mem_req),
        .mem_wr_en     (fsm_mem_wr_en),
        .resp_valid    (fsm_resp_valid),
        .busy          (fsm_busy),
        .refill_en     (fsm_refill_en),
        .current_state (fsm_state)
    );

    // 10ns clock period (100 MHz)
    always #5 clk = ~clk;

    // Helper task to verify assertions
    task check_cond;
        input condition;
        input [8*90-1:0] msg;
        begin
            total_tests = total_tests + 1;
            if (condition) begin
                passed_tests = passed_tests + 1;
                $display("[PASS] %0s", msg);
            end else begin
                failed_tests = failed_tests + 1;
                $display("[FAIL] %0s (at time %0t)", msg, $time);
            end
        end
    endtask

    // Helper task to simulate a single-cycle LRU access event
    task lru_access;
        input [1:0] s_idx;
        input       w_acc;
        begin
            @(negedge clk);
            set_index    = s_idx;
            access_valid = 1'b1;
            access_way   = w_acc;
            @(posedge clk);
            #1;
            access_valid = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("waveforms/lru_fsm.vcd");
        $dumpvars(0, tb_lru_fsm);

        // Initialize signals
        clk           = 1'b0;
        rst_n         = 1'b0;
        set_index     = 2'b00;
        access_valid  = 1'b0;
        access_way    = 1'b0;
        way0_valid    = 1'b0;
        way1_valid    = 1'b0;
        fsm_req_valid = 1'b0;
        fsm_req_wr_en = 1'b0;
        fsm_cache_hit = 1'b0;
        fsm_mem_ready = 1'b0;

        total_tests   = 0;
        passed_tests  = 0;
        failed_tests  = 0;

        $display("===============================================================================");
        $display("VERIFICATION SUITE: LRU CONTROLLER & CACHE FSM");
        $display("===============================================================================");

        // ---------------------------------------------------------------------
        // TEST 1 & 8: Reset of all LRU state & initial empty set
        // ---------------------------------------------------------------------
        #12;
        rst_n = 1'b1;
        #2;
        check_cond(lru_state_all == 4'b0000, "Reset initializes all 4 set LRU bits to 0");
        check_cond(fsm_state == 3'b000 && fsm_busy == 1'b0, "FSM resets to STATE_IDLE with busy=0");

        // ---------------------------------------------------------------------
        // TEST 2 & 6: First access to empty set & Invalid-way preference
        // ---------------------------------------------------------------------
        set_index  = 2'b00;
        way0_valid = 1'b0;
        way1_valid = 1'b0;
        #1;
        check_cond(victim_way == 1'b0, "Empty set (0,0) prefers Way 0 first");

        // Way 0 valid, Way 1 invalid -> must prefer Way 1 even if LRU=0
        way0_valid = 1'b1;
        way1_valid = 1'b0;
        #1;
        check_cond(victim_way == 1'b1, "Invalid-way preference picks Way 1 when Way 0 is valid");

        // Way 0 invalid, Way 1 valid -> must prefer Way 0 even if LRU=1
        lru_access(2'b00, 1'b0); // sets LRU[0] = 1
        way0_valid = 1'b0;
        way1_valid = 1'b1;
        #1;
        check_cond(victim_way == 1'b0, "Invalid-way preference picks Way 0 when Way 1 is valid");

        // ---------------------------------------------------------------------
        // TEST 3, 4, 5 & 7: Mandatory Trace (0x00 -> 0x10 -> 0x00 -> 0x20 in Set 0)
        // ---------------------------------------------------------------------
        $display("\n--- Running Mandatory Trace: 0x00 -> 0x10 -> 0x00 -> 0x20 (Set 0) ---");
        // Reset first
        @(negedge clk); rst_n = 1'b0;
        @(posedge clk); #1; rst_n = 1'b1;
        set_index = 2'b00;

        // Step 1: Access 0x00 (Miss on empty set -> allocates Way 0)
        way0_valid = 1'b0; way1_valid = 1'b0; #1;
        check_cond(victim_way == 1'b0, "Trace Step 1 (0x00): Empty set selects Way 0");
        lru_access(2'b00, 1'b0);
        check_cond(lru_state_all[0] == 1'b1, "Trace Step 1 (0x00): Way 0 accessed -> LRU[0]=1 (Way 1 is LRU)");

        // Step 2: Access 0x10 (Miss -> Way 0 valid, Way 1 invalid -> allocates Way 1)
        way0_valid = 1'b1; way1_valid = 1'b0; #1;
        check_cond(victim_way == 1'b1, "Trace Step 2 (0x10): Invalid Way 1 selected");
        lru_access(2'b00, 1'b1);
        check_cond(lru_state_all[0] == 1'b0, "Trace Step 2 (0x10): Way 1 accessed -> LRU[0]=0 (Way 0 is LRU)");

        // Step 3: Access 0x00 (Hit in Way 0 -> Way 1 becomes LRU!)
        way0_valid = 1'b1; way1_valid = 1'b1;
        lru_access(2'b00, 1'b0);
        check_cond(lru_state_all[0] == 1'b1, "Trace Step 3 (0x00 Hit): Way 0 accessed -> LRU[0]=1 (Way 1 is LRU)");

        // Step 4: Access 0x20 (Miss when both ways valid -> evicts Way 1 = 0x10!)
        #1;
        check_cond(victim_way == 1'b1, "Trace Step 4 (0x20 Miss): Victim is Way 1 (0x10 evicted, 0x00 kept)");
        lru_access(2'b00, 1'b1);
        check_cond(lru_state_all[0] == 1'b0, "Trace Step 4 (0x20 Refill): Way 1 refilled -> LRU[0]=0");

        // Verify independence across other sets (Set 1, Set 2, Set 3 remain 0)
        check_cond(lru_state_all[3:1] == 3'b000, "Other sets (1, 2, 3) remained undisturbed");

        // ---------------------------------------------------------------------
        // TEST 9: Cache FSM State Transitions (Hit, Read Miss, Write-Through)
        // ---------------------------------------------------------------------
        $display("\n--- Running Cache FSM State Transition Tests ---");
        // A. Read Hit Path: IDLE -> LOOKUP -> HIT_RESPONSE -> IDLE
        @(negedge clk);
        fsm_req_valid = 1'b1;
        fsm_req_wr_en = 1'b0;
        fsm_cache_hit = 1'b1;
        @(posedge clk); #1; // Now in LOOKUP
        check_cond(fsm_state == 3'b001 && fsm_busy == 1'b1, "FSM enters LOOKUP with busy=1");
        fsm_req_valid = 1'b0;
        @(posedge clk); #1; // Now in HIT_RESPONSE
        check_cond(fsm_state == 3'b010 && fsm_resp_valid == 1'b1, "FSM enters HIT_RESPONSE with resp_valid=1");
        @(posedge clk); #1; // Now back in IDLE
        check_cond(fsm_state == 3'b000 && fsm_busy == 1'b0, "FSM returns to IDLE after HIT_RESPONSE");

        // B. Read Miss Path: IDLE -> LOOKUP -> MEMORY_WAIT -> REFILL -> RESPONSE -> IDLE
        @(negedge clk);
        fsm_req_valid = 1'b1;
        fsm_req_wr_en = 1'b0;
        fsm_cache_hit = 1'b0;
        fsm_mem_ready = 1'b0;
        @(posedge clk); #1; // LOOKUP
        fsm_req_valid = 1'b0;
        @(posedge clk); #1; // MEMORY_WAIT
        check_cond(fsm_state == 3'b011 && fsm_mem_req == 1'b1 && fsm_mem_wr_en == 1'b0, "FSM enters MEMORY_WAIT for read miss");
        @(posedge clk); #1; // Still in MEMORY_WAIT because mem_ready=0
        check_cond(fsm_state == 3'b011, "FSM stalls in MEMORY_WAIT while mem_ready=0");
        @(negedge clk); fsm_mem_ready = 1'b1;
        @(posedge clk); #1; // REFILL
        check_cond(fsm_state == 3'b100 && fsm_refill_en == 1'b1, "FSM enters REFILL with refill_en=1");
        fsm_mem_ready = 1'b0;
        @(posedge clk); #1; // RESPONSE
        check_cond(fsm_state == 3'b101 && fsm_resp_valid == 1'b1, "FSM enters RESPONSE with resp_valid=1");
        @(posedge clk); #1; // IDLE
        check_cond(fsm_state == 3'b000 && fsm_busy == 1'b0, "FSM returns to IDLE after read miss");

        // C. Write-Through Path: IDLE -> LOOKUP -> MEMORY_WAIT -> RESPONSE -> IDLE
        @(negedge clk);
        fsm_req_valid = 1'b1;
        fsm_req_wr_en = 1'b1;
        fsm_cache_hit = 1'b0;
        fsm_mem_ready = 1'b1;
        @(posedge clk); #1; // LOOKUP
        fsm_req_valid = 1'b0;
        @(posedge clk); #1; // MEMORY_WAIT
        check_cond(fsm_state == 3'b011 && fsm_mem_req == 1'b1 && fsm_mem_wr_en == 1'b1, "FSM enters MEMORY_WAIT with mem_wr_en=1");
        @(posedge clk); #1; // RESPONSE (skips REFILL on write)
        check_cond(fsm_state == 3'b101 && fsm_resp_valid == 1'b1 && fsm_refill_en == 1'b0, "FSM skips REFILL on write and asserts resp_valid=1");
        @(posedge clk); #1; // IDLE
        check_cond(fsm_state == 3'b000, "FSM returns to IDLE after write-through");

        $display("\n===============================================================================");
        $display("VERIFICATION SUMMARY (LRU & FSM):");
        $display("Total Tests  : %0d", total_tests);
        $display("Tests Passed : %0d", passed_tests);
        $display("Tests Failed : %0d", failed_tests);
        $display("===============================================================================");
        if (failed_tests == 0)
            $display(">>> ALL LRU & FSM TESTS PASSED SUCCESSFULLY! <<<");
        else
            $display(">>> SOME TESTS FAILED! <<<");

        $finish;
    end

endmodule

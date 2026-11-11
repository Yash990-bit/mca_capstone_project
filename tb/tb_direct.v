// =============================================================================
// Testbench: tb_direct
// Project: Design and Performance Analysis of a 2-Way Set-Associative Cache
//          with LRU Replacement Compared with a Direct-Mapped Cache
// Component: Module-Level Verification for Direct-Mapped Cache Baseline
// Assigned Member: Shivam (RTL Engineer - Direct-Mapped Cache)
// Verification Lead: Kaavya
// Language: Verilog-2001
// =============================================================================

`timescale 1ns / 1ps

module tb_direct;

    // -------------------------------------------------------------------------
    // Clock & Reset Signals
    // -------------------------------------------------------------------------
    reg        clk;
    reg        rst_n;

    // -------------------------------------------------------------------------
    // CPU Interface Signals
    // -------------------------------------------------------------------------
    reg        req_valid;
    reg  [7:0] req_addr;
    reg        req_wr_en;
    reg  [7:0] req_wdata;
    wire [7:0] resp_rdata;
    wire       resp_valid;
    wire       cache_hit;
    wire       busy;

    // -------------------------------------------------------------------------
    // Backing Memory Interface Signals
    // -------------------------------------------------------------------------
    wire       mem_req;
    wire       mem_wr_en;
    wire [7:0] mem_addr;
    wire [7:0] mem_wdata;
    reg  [7:0] mem_rdata;
    reg        mem_ready;

    // -------------------------------------------------------------------------
    // Testbench Statistics & Bookkeeping
    // -------------------------------------------------------------------------
    integer total_tests;
    integer passed_tests;
    integer failed_tests;
    integer i;

    // =========================================================================
    // Device Under Test (DUT) Instantiation
    // =========================================================================
    cache_direct u_cache_direct (
        .clk        (clk),
        .rst_n      (rst_n),
        .req_valid  (req_valid),
        .req_addr   (req_addr),
        .req_wr_en  (req_wr_en),
        .req_wdata  (req_wdata),
        .resp_rdata (resp_rdata),
        .resp_valid (resp_valid),
        .cache_hit  (cache_hit),
        .busy       (busy),
        .mem_req    (mem_req),
        .mem_wr_en  (mem_wr_en),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_rdata  (mem_rdata),
        .mem_ready  (mem_ready)
    );

    // =========================================================================
    // Clock Generation: 100 MHz (Period = 10ns)
    // =========================================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // Synchronous Backing Memory Model (256 x 8-bit RAM)
    // Latency: 1 clock cycle for read and write transactions
    // =========================================================================
    reg [7:0] main_memory [0:255];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b0;
            mem_rdata <= 8'h00;
        end else begin
            if (mem_req && !mem_ready) begin
                // Synchronous memory response after 1 cycle of request
                mem_ready <= 1'b1;
                if (mem_wr_en) begin
                    main_memory[mem_addr] <= mem_wdata;
                end else begin
                    mem_rdata <= main_memory[mem_addr];
                end
            end else begin
                mem_ready <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Verification Tasks
    // =========================================================================

    // Task: Perform CPU Read and Validate Response
    task cpu_read;
        input  [7:0] addr;
        input  [7:0] exp_data;
        input        exp_hit;
        input  [80*8:1] test_desc;
        reg    [7:0] captured_data;
        reg          captured_hit;
        integer timeout;
        begin
            total_tests = total_tests + 1;
            timeout = 0;

            @(posedge clk);
            req_addr  <= addr;
            req_wr_en <= 1'b0;
            req_valid <= 1'b1;

            // Wait for cache response or completion
            @(posedge clk);
            while (!resp_valid && timeout < 20) begin
                timeout = timeout + 1;
                @(posedge clk);
            end

            captured_data = resp_rdata;
            captured_hit  = cache_hit;
            req_valid     <= 1'b0;

            if (timeout >= 20) begin
                $display("[FAIL] %0s | Addr: 0x%02h | TIMEOUT: No resp_valid received!", test_desc, addr);
                failed_tests = failed_tests + 1;
            end else if ((captured_data === exp_data) && (captured_hit === exp_hit)) begin
                $display("[PASS] %0s | Addr: 0x%02h (Tag=%0d, Idx=%0d) | Data: 0x%02h | Hit: %0b",
                         test_desc, addr, addr[7:3], addr[2:0], captured_data, captured_hit);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[FAIL] %0s | Addr: 0x%02h | Exp Data: 0x%02h, Got: 0x%02h | Exp Hit: %0b, Got: %0b",
                         test_desc, addr, exp_data, captured_data, exp_hit, captured_hit);
                failed_tests = failed_tests + 1;
            end
        end
    endtask

    // Task: Perform CPU Write and Validate Write-Through & Memory Content
    task cpu_write;
        input  [7:0] addr;
        input  [7:0] wdata;
        input        exp_hit;
        input  [80*8:1] test_desc;
        reg          captured_hit;
        integer timeout;
        begin
            total_tests = total_tests + 1;
            timeout = 0;

            @(posedge clk);
            req_addr  <= addr;
            req_wdata <= wdata;
            req_wr_en <= 1'b1;
            req_valid <= 1'b1;

            // Wait for cache write response
            @(posedge clk);
            while (!resp_valid && timeout < 20) begin
                timeout = timeout + 1;
                @(posedge clk);
            end

            captured_hit = cache_hit;
            req_valid    <= 1'b0;

            if (timeout >= 20) begin
                $display("[FAIL] %0s | Addr: 0x%02h | TIMEOUT: No resp_valid on write!", test_desc, addr);
                failed_tests = failed_tests + 1;
            end else if ((captured_hit === exp_hit) && (main_memory[addr] === wdata)) begin
                $display("[PASS] %0s | Addr: 0x%02h | WData: 0x%02h | Hit: %0b | MainMem: 0x%02h",
                         test_desc, addr, wdata, captured_hit, main_memory[addr]);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[FAIL] %0s | Addr: 0x%02h | Exp Hit: %0b, Got: %0b | MainMem Exp: 0x%02h, Got: 0x%02h",
                         test_desc, addr, exp_hit, captured_hit, wdata, main_memory[addr]);
                failed_tests = failed_tests + 1;
            end
        end
    endtask

    // =========================================================================
    // Waveform Dumping for GTKWave
    // =========================================================================
    initial begin
        $dumpfile("waveforms/direct_cache.vcd");
        $dumpvars(0, tb_direct);
    end

    // =========================================================================
    // Main Verification Stimulus
    // =========================================================================
    initial begin
        $display("===============================================================================");
        $display("STARTING VERIFICATION SUITE: DIRECT-MAPPED CACHE BASELINE");
        $display("RTL: rtl/cache_direct.v | Testbench: tb/tb_direct.v");
        $display("Author: Shivam (Direct-Mapped RTL Owner)");
        $display("===============================================================================");

        total_tests  = 0;
        passed_tests = 0;
        failed_tests = 0;

        // Initialize backing main memory with deterministic test data pattern:
        // Pattern: main_memory[addr] = addr ^ 8'h5A (unique, non-zero byte per address)
        for (i = 0; i < 256; i = i + 1) begin
            main_memory[i] = (i ^ 8'h5A);
        end

        // Initialize CPU inputs
        req_valid = 1'b0;
        req_addr  = 8'h00;
        req_wr_en = 1'b0;
        req_wdata = 8'h00;

        // ---------------------------------------------------------------------
        // TEST CASE 9: Reset Behavior and Initial State Verification
        // ---------------------------------------------------------------------
        $display("\n--- [TEST CASE 9]: RESET BEHAVIOR AND INITIALIZATION ---");
        rst_n = 1'b0; // Assert reset
        #25;
        rst_n = 1'b1; // De-assert reset
        @(posedge clk);

        // Verify all valid bits are cleared (0)
        total_tests = total_tests + 1;
        if (u_cache_direct.valid_array[0] == 1'b0 &&
            u_cache_direct.valid_array[1] == 1'b0 &&
            u_cache_direct.valid_array[2] == 1'b0 &&
            u_cache_direct.valid_array[3] == 1'b0 &&
            u_cache_direct.valid_array[4] == 1'b0 &&
            u_cache_direct.valid_array[5] == 1'b0 &&
            u_cache_direct.valid_array[6] == 1'b0 &&
            u_cache_direct.valid_array[7] == 1'b0 &&
            u_cache_direct.busy == 1'b0           &&
            u_cache_direct.resp_valid == 1'b0) begin
            $display("[PASS] Reset Initialization: All 8 valid bits cleared, state is IDLE.");
            passed_tests = passed_tests + 1;
        end else begin
            $display("[FAIL] Reset Initialization: Valid bits or state not clean after reset!");
            failed_tests = failed_tests + 1;
        end

        // ---------------------------------------------------------------------
        // TEST CASE 1: Cold Read Miss
        // Address 0x12 -> Tag = 5'b00010 (2), Index = 3'b010 (2).
        // Expected: Miss (Hit=0), Fetches from Memory, Data = 0x12 ^ 0x5A = 0x48.
        // ---------------------------------------------------------------------
        $display("\n--- [TEST CASE 1]: COLD READ MISS ---");
        cpu_read(8'h12, (8'h12 ^ 8'h5A), 1'b0, "Cold Read Miss (Addr 0x12)");

        // ---------------------------------------------------------------------
        // TEST CASE 2: Repeated Read Hit
        // Address 0x12 -> Line 2 now contains Tag 2 and Data 0x48.
        // Expected: Hit (Hit=1), Single-cycle response, Data = 0x48.
        // ---------------------------------------------------------------------
        $display("\n--- [TEST CASE 2]: REPEATED READ HIT ---");
        cpu_read(8'h12, (8'h12 ^ 8'h5A), 1'b1, "Repeated Read Hit (Addr 0x12)");
        cpu_read(8'h12, (8'h12 ^ 8'h5A), 1'b1, "Second Read Hit  (Addr 0x12)");

        // ---------------------------------------------------------------------
        // TEST CASE 3 & 4: Two Addresses Mapping to Same Index & Conflict Miss
        // Address A: 0x12 (Tag = 5'd2, Index = 3'd2) -> Currently in Line 2.
        // Address B: 0x32 (Tag = 5'd6, Index = 3'd2) -> Maps to Line 2!
        // Expected: Conflict Miss on 0x32, overwrites Line 2 with Tag 6.
        // Then read 0x12 again -> Conflict Miss on 0x12, evicting Tag 6.
        // Demonstrates direct-mapped ping-pong conflict thrashing.
        // ---------------------------------------------------------------------
        $display("\n--- [TEST CASE 3 & 4]: SAME INDEX MAPPING & CONFLICT MISS ---");
        $display("Addr 0x12: Tag=2, Index=2 | Addr 0x32: Tag=6, Index=2");
        cpu_read(8'h32, (8'h32 ^ 8'h5A), 1'b0, "Conflict Miss: Overwriting Line 2 (Addr 0x32)");
        cpu_read(8'h32, (8'h32 ^ 8'h5A), 1'b1, "Subsequent Read Hit on New Line (Addr 0x32)");
        cpu_read(8'h12, (8'h12 ^ 8'h5A), 1'b0, "Conflict Miss: Evicting Line 2 Back to Addr 0x12");
        cpu_read(8'h12, (8'h12 ^ 8'h5A), 1'b1, "Subsequent Read Hit on Refilled Addr 0x12");

        // ---------------------------------------------------------------------
        // TEST CASE 5: Different Addresses Mapping to Different Indices
        // Access 8 different addresses with distinct indices [0..7]:
        // Addr 0x00 -> Idx 0, Tag 0
        // Addr 0x01 -> Idx 1, Tag 0
        // Addr 0x02 -> Idx 2, Tag 0
        // Addr 0x03 -> Idx 3, Tag 0
        // Addr 0x04 -> Idx 4, Tag 0
        // Addr 0x05 -> Idx 5, Tag 0
        // Addr 0x06 -> Idx 6, Tag 0
        // Addr 0x07 -> Idx 7, Tag 0
        // All 8 entries should fill without conflict!
        // ---------------------------------------------------------------------
        $display("\n--- [TEST CASE 5]: POPULATING ALL 8 CACHE LINES (NO CONFLICTS) ---");
        cpu_read(8'h00, (8'h00 ^ 8'h5A), 1'b0, "Cold Miss Fill Line 0 (0x00)");
        cpu_read(8'h01, (8'h01 ^ 8'h5A), 1'b0, "Cold Miss Fill Line 1 (0x01)");
        cpu_read(8'h02, (8'h02 ^ 8'h5A), 1'b0, "Cold Miss Fill Line 2 (0x02)");
        cpu_read(8'h03, (8'h03 ^ 8'h5A), 1'b0, "Cold Miss Fill Line 3 (0x03)");
        cpu_read(8'h04, (8'h04 ^ 8'h5A), 1'b0, "Cold Miss Fill Line 4 (0x04)");
        cpu_read(8'h05, (8'h05 ^ 8'h5A), 1'b0, "Cold Miss Fill Line 5 (0x05)");
        cpu_read(8'h06, (8'h06 ^ 8'h5A), 1'b0, "Cold Miss Fill Line 6 (0x06)");
        cpu_read(8'h07, (8'h07 ^ 8'h5A), 1'b0, "Cold Miss Fill Line 7 (0x07)");

        // ---------------------------------------------------------------------
        // TEST CASE 6: Read-Data Correctness Across Full Capacity
        // Now re-read all 8 populated lines; all must be hits with exact data!
        // ---------------------------------------------------------------------
        $display("\n--- [TEST CASE 6]: READ DATA CORRECTNESS & 100%% HIT VERIFICATION ---");
        cpu_read(8'h00, (8'h00 ^ 8'h5A), 1'b1, "Read Hit Verify Line 0 (0x00)");
        cpu_read(8'h01, (8'h01 ^ 8'h5A), 1'b1, "Read Hit Verify Line 1 (0x01)");
        cpu_read(8'h02, (8'h02 ^ 8'h5A), 1'b1, "Read Hit Verify Line 2 (0x02)");
        cpu_read(8'h03, (8'h03 ^ 8'h5A), 1'b1, "Read Hit Verify Line 3 (0x03)");
        cpu_read(8'h04, (8'h04 ^ 8'h5A), 1'b1, "Read Hit Verify Line 4 (0x04)");
        cpu_read(8'h05, (8'h05 ^ 8'h5A), 1'b1, "Read Hit Verify Line 5 (0x05)");
        cpu_read(8'h06, (8'h06 ^ 8'h5A), 1'b1, "Read Hit Verify Line 6 (0x06)");
        cpu_read(8'h07, (8'h07 ^ 8'h5A), 1'b1, "Read Hit Verify Line 7 (0x07)");

        // ---------------------------------------------------------------------
        // TEST CASE 7: Write Hit (Write-Through Policy)
        // Address 0x03 is currently in cache Line 3.
        // Write 0xDE to Address 0x03.
        // Expected:
        // - Cache Hit (Hit=1)
        // - Cache Line 3 updated with 0xDE
        // - Main memory location 0x03 updated with 0xDE (Write-Through)
        // - Subsequent read to 0x03 returns 0xDE on a cache hit!
        // ---------------------------------------------------------------------
        $display("\n--- [TEST CASE 7]: WRITE HIT (WRITE-THROUGH) ---");
        cpu_write(8'h03, 8'hDE, 1'b1, "Write Hit (Addr 0x03, Data 0xDE)");
        cpu_read (8'h03, 8'hDE, 1'b1, "Subsequent Read Hit to Written Addr (0x03)");

        // ---------------------------------------------------------------------
        // TEST CASE 8: Write Miss (No-Write-Allocate Policy)
        // Address 0x88 -> Tag = 5'd17, Index = 3'd0.
        // Line 0 currently holds Tag 0 (Address 0x00).
        // Write 0xBE to Address 0x88.
        // Expected:
        // - Cache Miss (Hit=0)
        // - Line 0 is NOT updated or allocated (No-Write-Allocate)
        // - Main memory location 0x88 updated with 0xBE
        // - Reading Line 0 (0x00) is STILL a hit with original data!
        // - Reading 0x88 results in a Read Miss, then fetches 0xBE from memory.
        // ---------------------------------------------------------------------
        $display("\n--- [TEST CASE 8]: WRITE MISS (NO-WRITE-ALLOCATE) ---");
        cpu_write(8'h88, 8'hBE, 1'b0, "Write Miss (Addr 0x88, Data 0xBE)");

        // Verify Line 0 was NOT overwritten by Write Miss to 0x88
        cpu_read(8'h00, (8'h00 ^ 8'h5A), 1'b1, "Verify Line 0 Unchanged by Write Miss");

        // Now read 0x88: Must miss, fetch written value 0xBE from memory, and allocate
        cpu_read(8'h88, 8'hBE, 1'b0, "Read Miss on 0x88 (Fetches Written 0xBE from Memory)");
        cpu_read(8'h88, 8'hBE, 1'b1, "Subsequent Read Hit on 0x88");

        // ---------------------------------------------------------------------
        // TEST CASE 9 (Re-verification): Reset Invalidation During Active State
        // Invalidate cache via reset and confirm previous hits turn to cold misses.
        // ---------------------------------------------------------------------
        $display("\n--- [TEST CASE 9]: RE-TEST RESET INVALIDATION ---");
        @(posedge clk);
        rst_n = 1'b0;
        #20;
        rst_n = 1'b1;
        @(posedge clk);

        // Address 0x88 was cached prior to reset; it must now be a cold miss
        cpu_read(8'h88, 8'hBE, 1'b0, "Cold Miss After Reset on Previously Cached Addr");

        // ---------------------------------------------------------------------
        // Final Summary
        // ---------------------------------------------------------------------
        $display("\n===============================================================================");
        $display("VERIFICATION SUMMARY FOR DIRECT-MAPPED CACHE:");
        $display("Total Tests Executed : %0d", total_tests);
        $display("Tests Passed         : %0d", passed_tests);
        $display("Tests Failed         : %0d", failed_tests);
        if (failed_tests == 0) begin
            $display(">>> ALL TESTS PASSED SUCCESSFULLY! DIRECT-MAPPED CACHE MEETS ALL REQUIREMENTS. <<<");
        end else begin
            $display(">>> SOME TESTS FAILED! CHECK SIMULATION LOG. <<<");
        end
        $display("===============================================================================\n");

        #50;
        $finish;
    end

endmodule

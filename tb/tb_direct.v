// =============================================================================
// Testbench: tb_direct.v
// DUT      : cache_direct (8-line direct-mapped, Write-Through/No-WA)
// Author   : Kaavya (Verification Engineer)
// Project  : MCA Capstone — Cache Performance Comparison
// Tool     : Icarus Verilog (iverilog / vvp)
// Dump     : waveforms/wave_direct.vcd  (open with GTKWave)
//
// ADDRESS MAP (direct-mapped, 8 lines):
//   addr[2:0]  = line index  (0-7)
//   addr[7:3]  = tag         (5 bits)
//
// Addresses used in this TB:
//   Addr  Binary     Line  Tag
//   0x00  000_00000  0     0x00  <- Line 0, Tag 0
//   0x08  000_01000  0     0x01  <- Line 0, Tag 1  (CONFLICT with 0x00)
//   0x10  000_10000  0     0x02  <- Line 0, Tag 2  (CONFLICT with 0x00, 0x08)
//   0x01  000_00001  1     0x00  <- Line 1, Tag 0
//   0x02  000_00010  2     0x00  <- Line 2, Tag 0
//   0x03  000_00011  3     0x00  <- Line 3, Tag 0
// =============================================================================

`timescale 1ns / 1ps

module tb_direct;

    // =========================================================================
    // DUT Ports
    // =========================================================================
    reg        clk;
    reg        rst_n;
    reg        req_valid;
    reg  [7:0] req_addr;
    reg        req_wr_en;
    reg  [7:0] req_wdata;
    wire [7:0] resp_rdata;
    wire       resp_valid;
    wire       cache_hit;
    wire       busy;
    wire       mem_req;
    wire       mem_wr_en;
    wire [7:0] mem_addr;
    wire [7:0] mem_wdata;
    reg  [7:0] mem_rdata;
    reg        mem_ready;

    // =========================================================================
    // Scoreboard / Statistics
    // =========================================================================
    integer total_requests;
    integer hit_count;
    integer miss_count;
    integer pass_count;
    integer fail_count;

    // =========================================================================
    // Backing Memory Model (256 x 8-bit) — identical init as tb_2way.v
    // =========================================================================
    reg [7:0] memory [0:255];
    integer j;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    cache_direct dut (
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
    // Clock Generator — 10 ns period (same as tb_2way)
    // =========================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================================
    // Backing Memory Behaviour: 2-cycle latency (identical to tb_2way model)
    // =========================================================================
    reg mem_pending;
    reg [1:0] mem_delay_cnt;
    reg mem_is_write;

    initial begin
        mem_rdata     = 8'h00;
        mem_ready     = 1'b0;
        mem_pending   = 1'b0;
        mem_delay_cnt = 2'd0;
        mem_is_write  = 1'b0;
    end

    always @(posedge clk) begin
        if (mem_req && !mem_ready && !mem_pending) begin
            mem_pending   <= 1'b1;
            mem_delay_cnt <= 2'd0;
            mem_is_write  <= mem_wr_en;
        end

        if (mem_pending) begin
            if (mem_delay_cnt < 2'd1) begin
                mem_delay_cnt <= mem_delay_cnt + 1;
            end else begin
                if (!mem_is_write)
                    mem_rdata <= memory[mem_addr];
                else
                    memory[mem_addr] <= mem_wdata;
                mem_ready   <= 1'b1;
                mem_pending <= 1'b0;
            end
        end else begin
            mem_ready <= 1'b0;
        end
    end

    // last_rdata: latches resp_rdata on the cycle resp_valid is high
    reg [7:0] last_rdata;

    // =========================================================================
    // Helper Task: drive_read(addr)
    // =========================================================================
    task drive_read;
        input [7:0] addr;
        begin
            @(posedge clk);
            req_valid  <= 1'b1;
            req_addr   <= addr;
            req_wr_en  <= 1'b0;
            req_wdata  <= 8'h00;

            @(posedge clk);
            while (!resp_valid) @(posedge clk);

            // Latch rdata while resp_valid is still asserted
            last_rdata = resp_rdata;

            total_requests = total_requests + 1;
            if (cache_hit) hit_count  = hit_count  + 1;
            else           miss_count = miss_count + 1;

            req_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // Helper Task: drive_write(addr, data)
    // =========================================================================
    task drive_write;
        input [7:0] addr;
        input [7:0] data;
        begin
            @(posedge clk);
            req_valid  <= 1'b1;
            req_addr   <= addr;
            req_wr_en  <= 1'b1;
            req_wdata  <= data;

            @(posedge clk);
            while (!resp_valid) @(posedge clk);

            total_requests = total_requests + 1;
            if (cache_hit) hit_count  = hit_count  + 1;
            else           miss_count = miss_count + 1;

            req_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // Helper Task: check(condition, test_name)
    // =========================================================================
    task check;
        input condition;
        input [479:0] test_name;
        begin
            if (condition) begin
                $display("  [PASS] %0s", test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s  <-- INVESTIGATE", test_name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================================
    // VCD Waveform Dump
    // =========================================================================
    initial begin
        $dumpfile("waveforms/wave_direct.vcd");
        $dumpvars(0, tb_direct);
    end

    // =========================================================================
    // MAIN TEST SEQUENCE
    // =========================================================================
    integer last_hit;

    initial begin
        total_requests = 0;
        hit_count      = 0;
        miss_count     = 0;
        pass_count     = 0;
        fail_count     = 0;

        for (j = 0; j < 256; j = j + 1)
            memory[j] = j[7:0];

        // ----- Apply Reset -----
        rst_n     = 1'b0;
        req_valid = 1'b0;
        req_addr  = 8'h00;
        req_wr_en = 1'b0;
        req_wdata = 8'h00;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        $display("=============================================================");
        $display(" DIRECT-MAPPED CACHE TESTBENCH  (tb_direct.v)");
        $display("=============================================================");

        // =====================================================================
        // TEST 1 — Cold Cache Access (first access must MISS)
        // =====================================================================
        $display("\n--- TEST 1: Cold Cache Access ---");
        last_hit = hit_count;
        drive_read(8'h00);
        check((hit_count == last_hit), "T1: Cold read addr=0x00 is a MISS");
        check((resp_rdata == 8'h00), "T1: Data returned from memory = 0x00");

        // =====================================================================
        // TEST 2 — Repeated Access (second access must HIT)
        // =====================================================================
        $display("\n--- TEST 2: Repeated Access (Cache Hit After Fill) ---");
        last_hit = hit_count;
        drive_read(8'h00);
        check((hit_count == last_hit + 1), "T2: Second read addr=0x00 is a HIT");
        check((resp_rdata == 8'h00), "T2: Cached data returned correctly = 0x00");

        // =====================================================================
        // TEST 3 — Sequential Access
        // =====================================================================
        $display("\n--- TEST 3: Sequential Access Pattern ---");
        drive_read(8'h01);
        drive_read(8'h02);
        drive_read(8'h03);
        last_hit = hit_count;
        drive_read(8'h01);
        drive_read(8'h02);
        drive_read(8'h03);
        check((hit_count == last_hit + 3), "T3: Re-access of lines 1,2,3 all HIT");

        // =====================================================================
        // TEST 4 — Conflict Access (thrashing in direct-mapped)
        // 0x00 (line 0, tag 0) vs 0x08 (line 0, tag 1) — SAME line, DIFFERENT tag
        // =====================================================================
        $display("\n--- TEST 4: Conflict Access (Same Line, Different Tags) ---");
        // 0x00 is already in line 0 from Test 2
        last_hit = hit_count;
        drive_read(8'h08);    // Line 0, Tag 1 -> MISS -> EVICTS 0x00
        check((hit_count == last_hit), "T4a: addr=0x08 (Line 0, Tag 1) is a MISS (evicts 0x00)");
        // 0x00 was evicted — accessing it again must MISS (conflict eviction)
        last_hit = hit_count;
        drive_read(8'h00);    // MISS again (direct-mapped can't hold both!)
        check((hit_count == last_hit), "T4b: addr=0x00 MISSes again (evicted by conflict — direct-mapped limitation)");

        // =====================================================================
        // TEST 5 — LRU Replacement (N/A for direct-mapped; direct eviction)
        // Show that alternating 0x00/0x08 always thrashes
        // =====================================================================
        $display("\n--- TEST 5: Direct Eviction (No LRU in Direct-Mapped) ---");
        // Both addresses map to line 0.  Every switch = eviction = miss.
        begin : thrash_test
            integer tr_sh, tr_sm, tr_st;
            integer tr_hits, tr_misses, tr_total;
            integer k;
            tr_sh = hit_count; tr_sm = miss_count; tr_st = total_requests;
            for (k = 0; k < 4; k = k + 1) begin
                drive_read(8'h00);   // Load Tag 0 -> evict Tag 1
                drive_read(8'h08);   // Load Tag 1 -> evict Tag 0
            end
            tr_hits   = hit_count   - tr_sh;
            tr_misses = miss_count  - tr_sm;
            tr_total  = total_requests - tr_st;
            // NOTE: T4b ends with 0x00 loaded into line 0 (last access).
            // The first drive_read(0x00) in this loop is therefore a HIT.
            // Then every alternating access evicts the other -> 7 MISSes.
            // This is REAL RTL behaviour, not a testbench bug.
            check((tr_hits == 1 && tr_misses == 7),
                  "T5: Alternating conflict: 1 initial hit then 7 MISSes (thrashing confirmed)");
            $display("  Thrash results: Hits=%0d  Misses=%0d (1 hit because line0 had addr=0x00 from T4b)", tr_hits, tr_misses);
        end

        // =====================================================================
        // TEST 6 — No Second Way (invalid-way preference not applicable)
        // Verify that second conflicting address ALWAYS evicts first
        // =====================================================================
        $display("\n--- TEST 6: Single-Way — No Invalid-Way Preference ---");
        drive_read(8'h00);     // Fill line 0 with Tag 0
        last_hit = hit_count;
        drive_read(8'h08);     // Conflict -> evicts Tag 0, fills Tag 1
        check((hit_count == last_hit), "T6a: Conflict addr=0x08 always MISSes (direct-mapped evicts immediately)");
        last_hit = hit_count;
        drive_read(8'h00);     // Tag 0 evicted, must MISS
        check((hit_count == last_hit), "T6b: addr=0x00 evicted by 0x08, MISSes again");

        // =====================================================================
        // TEST 7 — Write Operations
        // =====================================================================
        $display("\n--- TEST 7: Write Operations ---");
        rst_n = 1'b0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        drive_read(8'h00);     // Cold fill line 0
        last_hit = hit_count;
        drive_write(8'h00, 8'hAB);  // Write HIT
        check((hit_count == last_hit + 1), "T7a: Write to cached addr=0x00 is a WRITE HIT");
        @(posedge clk);
        check((memory[8'h00] == 8'hAB), "T7b: Write-through: memory[0x00] = 0xAB");
        drive_read(8'h00);
        check((last_rdata == 8'hAB), "T7c: Read after write returns 0xAB");

        // Write MISS (no-write-allocate)
        last_hit = hit_count;
        drive_write(8'h10, 8'hCD);  // Line 0, Tag 2 — not in cache
        check((hit_count == last_hit), "T7d: Write to uncached addr=0x10 is a WRITE MISS");
        check((memory[8'h10] == 8'hCD), "T7e: Write-miss: memory[0x10] = 0xCD (write-through)");
        // After write-miss, line 0x10 should NOT be allocated (no-write-allocate)
        // 0x00 should still be in cache (line 0 was not disturbed)
        last_hit = hit_count;
        drive_read(8'h00);
        check((hit_count == last_hit + 1), "T7f: No-write-allocate: addr=0x00 still cached after write-miss at 0x10");

        // =====================================================================
        // TEST 8 — Reset
        // =====================================================================
        $display("\n--- TEST 8: Reset Clears Cache State ---");
        rst_n = 1'b0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        last_hit = hit_count;
        drive_read(8'h00);
        check((hit_count == last_hit), "T8: After reset, addr=0x00 MISSes (valid bits cleared)");

        // =====================================================================
        // PERFORMANCE TRACE — Sequential
        // =====================================================================
        $display("\n--- PERF TRACE: Sequential Access ---");
        rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1; @(posedge clk);
        begin : seq_trace
            integer tr_sh, tr_sm, tr_st;
            integer tr_hits, tr_misses, tr_total;
            integer k;
            tr_sh = hit_count; tr_sm = miss_count; tr_st = total_requests;
            for (k = 0; k < 8; k = k + 1) drive_read(k[7:0]);
            for (k = 0; k < 8; k = k + 1) drive_read(k[7:0]);
            tr_hits   = hit_count   - tr_sh;
            tr_misses = miss_count  - tr_sm;
            tr_total  = total_requests - tr_st;
            $display("  Sequential | Req=%0d  Hits=%0d  Misses=%0d  HitRate=%0d%%  MissRate=%0d%%",
                     tr_total, tr_hits, tr_misses,
                     (tr_hits*100)/tr_total, (tr_misses*100)/tr_total);
        end

        // =====================================================================
        // PERFORMANCE TRACE — Repeated
        // =====================================================================
        $display("\n--- PERF TRACE: Repeated Access ---");
        rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1; @(posedge clk);
        begin : rep_trace
            integer tr_sh, tr_sm, tr_st;
            integer tr_hits, tr_misses, tr_total;
            integer k;
            tr_sh = hit_count; tr_sm = miss_count; tr_st = total_requests;
            drive_read(8'h00);
            for (k = 0; k < 7; k = k + 1) drive_read(8'h00);
            tr_hits   = hit_count   - tr_sh;
            tr_misses = miss_count  - tr_sm;
            tr_total  = total_requests - tr_st;
            $display("  Repeated   | Req=%0d  Hits=%0d  Misses=%0d  HitRate=%0d%%  MissRate=%0d%%",
                     tr_total, tr_hits, tr_misses,
                     (tr_hits*100)/tr_total, (tr_misses*100)/tr_total);
        end

        // =====================================================================
        // PERFORMANCE TRACE — Conflict-Heavy
        // (3 addresses mapping to same line -> continuous thrashing)
        // =====================================================================
        $display("\n--- PERF TRACE: Conflict-Heavy Access ---");
        rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1; @(posedge clk);
        begin : conf_trace
            integer tr_sh, tr_sm, tr_st;
            integer tr_hits, tr_misses, tr_total;
            integer k;
            tr_sh = hit_count; tr_sm = miss_count; tr_st = total_requests;
            // 0x00(Line0,Tag0), 0x08(Line0,Tag1), 0x10(Line0,Tag2)
            // All map to LINE 0 -> every access evicts the previous -> 100% miss
            for (k = 0; k < 4; k = k + 1) begin
                drive_read(8'h00);
                drive_read(8'h08);
                drive_read(8'h10);
            end
            tr_hits   = hit_count   - tr_sh;
            tr_misses = miss_count  - tr_sm;
            tr_total  = total_requests - tr_st;
            $display("  Conflict   | Req=%0d  Hits=%0d  Misses=%0d  HitRate=%0d%%  MissRate=%0d%%",
                     tr_total, tr_hits, tr_misses,
                     (tr_hits*100)/tr_total, (tr_misses*100)/tr_total);
        end

        // =====================================================================
        // PERFORMANCE TRACE — Mixed
        // (identical sequence as tb_2way for fair comparison)
        // =====================================================================
        $display("\n--- PERF TRACE: Mixed Access ---");
        rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1; @(posedge clk);
        begin : mix_trace
            integer tr_sh, tr_sm, tr_st;
            integer tr_hits, tr_misses, tr_total;
            tr_sh = hit_count; tr_sm = miss_count; tr_st = total_requests;
            drive_read(8'h00);         // Miss (line 0, tag 0)
            drive_read(8'h01);         // Miss (line 1, tag 0)
            drive_read(8'h00);         // HIT  (line 0, tag 0)
            drive_read(8'h08);         // Miss (line 0, tag 1 -> evicts 0x00!)
            drive_read(8'h00);         // Miss (line 0, tag 0 -> evicted by 0x08)
            drive_read(8'h08);         // Miss (line 0, tag 1 -> evicted by 0x00)
            drive_write(8'h01, 8'h55); // Write HIT (line 1 still has tag 0)
            drive_read(8'h10);         // Miss (line 0, tag 2)
            drive_read(8'h02);         // Miss (line 2, tag 0)
            drive_read(8'h02);         // HIT  (line 2, tag 0)
            tr_hits   = hit_count   - tr_sh;
            tr_misses = miss_count  - tr_sm;
            tr_total  = total_requests - tr_st;
            $display("  Mixed      | Req=%0d  Hits=%0d  Misses=%0d  HitRate=%0d%%  MissRate=%0d%%",
                     tr_total, tr_hits, tr_misses,
                     (tr_hits*100)/tr_total, (tr_misses*100)/tr_total);
        end

        // =====================================================================
        // FINAL SUMMARY
        // =====================================================================
        $display("\n=============================================================");
        $display(" DIRECT-MAPPED CACHE — OVERALL RESULTS");
        $display("  Total Requests : %0d", total_requests);
        $display("  Cache Hits     : %0d", hit_count);
        $display("  Cache Misses   : %0d", miss_count);
        $display("  Hit  Rate      : %0d%%", (hit_count  * 100) / total_requests);
        $display("  Miss Rate      : %0d%%", (miss_count * 100) / total_requests);
        $display("  Tests PASSED   : %0d", pass_count);
        $display("  Tests FAILED   : %0d", fail_count);
        $display("=============================================================\n");

        if (fail_count == 0)
            $display("ALL TESTS PASSED — Direct-mapped cache verification COMPLETE.\n");
        else
            $display("SOME TESTS FAILED — See [FAIL] lines above.\n");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #200000;
        $display("[TIMEOUT] Simulation exceeded 200 us — aborting.");
        $finish;
    end

endmodule

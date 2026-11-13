// =============================================================================
// Testbench: tb_2way.v
// DUT      : cache_2way (4-set, 2-way set-associative, Write-Through/No-WA)
// Author   : Kaavya (Verification Engineer)
// Project  : MCA Capstone — Cache Performance Comparison
// Tool     : Icarus Verilog (iverilog / vvp)
// Dump     : waveforms/wave_2way.vcd  (open with GTKWave)
//
// ADDRESS MAP (2-way, 4 sets):
//   addr[1:0]  = set index   (0-3)
//   addr[7:2]  = tag         (6 bits)
//
// Addresses used in this TB:
//   Addr  Binary     Set  Tag
//   0x00  00_00_00   0    0x00   <- Set 0, Tag 0
//   0x04  00_01_00   0    0x01   <- Set 0, Tag 1  (conflicts with 0x00 in set 0)
//   0x08  00_10_00   0    0x02   <- Set 0, Tag 2  (3rd way -> triggers LRU eviction)
//   0x01  00_00_01   1    0x00   <- Set 1, Tag 0
//   0x05  00_01_01   1    0x01   <- Set 1, Tag 1  (conflicts with 0x01 in set 1)
//   0x09  00_10_01   1    0x02   <- Set 1, Tag 2  (3rd way -> triggers LRU eviction)
//   0x02  00_00_10   2    0x00   <- Set 2, Tag 0
//   0x03  00_00_11   3    0x00   <- Set 3, Tag 0
// =============================================================================

`timescale 1ns / 1ps

module tb_2way;

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
    // Backing Memory Model (256 x 8-bit)
    // =========================================================================
    reg [7:0] memory [0:255];
    integer j;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    cache_2way dut (
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
    // Clock Generator — 10 ns period
    // =========================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================================
    // Backing Memory Behaviour: 2-cycle read latency, 1-cycle write latency
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

            // Latch rdata while resp_valid is still asserted (combinational window)
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
        $dumpfile("waveforms/wave_2way.vcd");
        $dumpvars(0, tb_2way);
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
        $display(" 2-WAY SET-ASSOCIATIVE CACHE TESTBENCH  (tb_2way.v)");
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
        check((hit_count == last_hit + 3), "T3: Re-access of sets 1,2,3 all HIT");

        // =====================================================================
        // TEST 4 — Conflict Accesses (same set, different tags)
        // =====================================================================
        $display("\n--- TEST 4: Conflict Access (Same Set, Different Tags) ---");
        last_hit = hit_count;
        drive_read(8'h04);
        check((hit_count == last_hit), "T4a: addr=0x04 (Set 0, Tag 1) is a MISS");
        last_hit = hit_count;
        drive_read(8'h00);
        drive_read(8'h04);
        check((hit_count == last_hit + 2), "T4b: Both conflicting lines coexist and HIT");

        // =====================================================================
        // TEST 5 — LRU Replacement
        // =====================================================================
        $display("\n--- TEST 5: LRU Replacement ---");
        drive_read(8'h00);        // Way0=MRU, Way1=LRU
        last_hit = hit_count;
        drive_read(8'h08);        // MISS -> evicts LRU (Way1=0x04)
        check((hit_count == last_hit), "T5a: addr=0x08 is a MISS (triggers LRU eviction)");
        last_hit = hit_count;
        drive_read(8'h08);
        check((hit_count == last_hit + 1), "T5b: addr=0x08 HITs after fill");
        last_hit = hit_count;
        drive_read(8'h00);
        check((hit_count == last_hit + 1), "T5c: addr=0x00 still HITs (was MRU)");
        last_hit = hit_count;
        drive_read(8'h04);
        check((hit_count == last_hit), "T5d: addr=0x04 MISSes (was LRU victim, evicted)");

        // =====================================================================
        // TEST 6 — Invalid-Way Preference
        // =====================================================================
        $display("\n--- TEST 6: Invalid-Way Preference After Reset ---");
        rst_n = 1'b0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        drive_read(8'h05);
        drive_read(8'h09);
        last_hit = hit_count;
        drive_read(8'h05);
        drive_read(8'h09);
        check((hit_count == last_hit + 2), "T6: Invalid-way preference: both lines cached and HIT");

        // =====================================================================
        // TEST 7 — Write Operations
        // =====================================================================
        $display("\n--- TEST 7: Write Operations ---");
        rst_n = 1'b0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        drive_read(8'h00);
        last_hit = hit_count;
        drive_write(8'h00, 8'hAB);
        check((hit_count == last_hit + 1), "T7a: Write to cached addr=0x00 is a WRITE HIT");
        @(posedge clk);
        check((memory[8'h00] == 8'hAB), "T7b: Write-through: memory[0x00] = 0xAB");
        // Read back — drive_read sets resp_rdata on resp_valid cycle; sample AFTER the task
        drive_read(8'h00);
        // last_rdata was latched inside drive_read on the resp_valid cycle
        check((last_rdata == 8'hAB), "T7c: Read after write returns 0xAB (latched during resp_valid)");

        last_hit = hit_count;
        drive_write(8'h10, 8'hCD);
        check((hit_count == last_hit), "T7d: Write to uncached addr=0x10 is a WRITE MISS");
        check((memory[8'h10] == 8'hCD), "T7e: Write-miss: memory[0x10] = 0xCD (write-through)");

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
        // =====================================================================
        $display("\n--- PERF TRACE: Conflict-Heavy Access ---");
        rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1; @(posedge clk);
        begin : conf_trace
            integer tr_sh, tr_sm, tr_st;
            integer tr_hits, tr_misses, tr_total;
            integer k;
            tr_sh = hit_count; tr_sm = miss_count; tr_st = total_requests;
            for (k = 0; k < 4; k = k + 1) begin
                drive_read(8'h00);
                drive_read(8'h04);
                drive_read(8'h08);
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
        // =====================================================================
        $display("\n--- PERF TRACE: Mixed Access ---");
        rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1; @(posedge clk);
        begin : mix_trace
            integer tr_sh, tr_sm, tr_st;
            integer tr_hits, tr_misses, tr_total;
            tr_sh = hit_count; tr_sm = miss_count; tr_st = total_requests;
            drive_read(8'h00);
            drive_read(8'h01);
            drive_read(8'h00);
            drive_read(8'h04);
            drive_read(8'h00);
            drive_read(8'h04);
            drive_write(8'h01, 8'h55);
            drive_read(8'h08);
            drive_read(8'h02);
            drive_read(8'h02);
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
        $display(" 2-WAY CACHE — OVERALL RESULTS");
        $display("  Total Requests : %0d", total_requests);
        $display("  Cache Hits     : %0d", hit_count);
        $display("  Cache Misses   : %0d", miss_count);
        $display("  Hit  Rate      : %0d%%", (hit_count  * 100) / total_requests);
        $display("  Miss Rate      : %0d%%", (miss_count * 100) / total_requests);
        $display("  Tests PASSED   : %0d", pass_count);
        $display("  Tests FAILED   : %0d", fail_count);
        $display("=============================================================\n");

        if (fail_count == 0)
            $display("ALL TESTS PASSED — 2-way cache verification COMPLETE.\n");
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

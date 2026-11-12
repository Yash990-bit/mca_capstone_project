`timescale 1ns / 1ps

// Standalone unit test for cache_2way. Kept separate from Kaavya's tb_2way.v.
module tb_cache_2way_keshav;
    reg clk;
    reg rst_n;
    reg req_valid;
    reg [7:0] req_addr;
    reg req_wr_en;
    reg [7:0] req_wdata;
    wire [7:0] resp_rdata;
    wire resp_valid;
    wire cache_hit;
    wire busy;
    wire mem_req;
    wire mem_wr_en;
    wire [7:0] mem_addr;
    wire [7:0] mem_wdata;
    wire [7:0] mem_rdata;
    wire mem_ready;

    reg [7:0] memory [0:255];
    integer n;
    integer checks;

    assign mem_ready = mem_req;
    assign mem_rdata = memory[mem_addr];

    cache_2way dut (
        .clk(clk), .rst_n(rst_n),
        .req_valid(req_valid), .req_addr(req_addr),
        .req_wr_en(req_wr_en), .req_wdata(req_wdata),
        .resp_rdata(resp_rdata), .resp_valid(resp_valid),
        .cache_hit(cache_hit), .busy(busy),
        .mem_req(mem_req), .mem_wr_en(mem_wr_en),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata), .mem_ready(mem_ready)
    );

    always #5 clk = ~clk;

    // The backing store accepts writes on the rising edge. Reads are
    // combinational in this small handshake model.
    always @(posedge clk) begin
        if (mem_req && mem_wr_en)
            memory[mem_addr] <= mem_wdata;
    end

    task check;
        input condition;
        input [8*100-1:0] message;
        begin
            checks = checks + 1;
            if (!condition) begin
                $display("FAIL: %0s at time %0t", message, $time);
                $fatal(1);
            end
            $display("PASS: %0s", message);
        end
    endtask

    task read_byte;
        input [7:0] address;
        input expected_hit;
        input [7:0] expected_data;
        input [8*100-1:0] label;
        integer cycles;
        begin
            @(negedge clk);
            req_valid = 1'b1;
            req_wr_en = 1'b0;
            req_addr = address;
            cycles = 0;
            while (!resp_valid && cycles < 8) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            #1;
            check(resp_valid, {label, " response"});
            check(cache_hit == expected_hit, {label, " hit status"});
            check(resp_rdata == expected_data, {label, " returned data"});
            @(negedge clk);
            req_valid = 1'b0;
        end
    endtask

    task write_byte;
        input [7:0] address;
        input [7:0] value;
        input expected_hit;
        integer cycles;
        begin
            @(negedge clk);
            req_valid = 1'b1;
            req_wr_en = 1'b1;
            req_addr = address;
            req_wdata = value;
            cycles = 0;
            while (!resp_valid && cycles < 8) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            #1;
            check(resp_valid, "write response");
            check(cache_hit == expected_hit, "write hit status");
            check(memory[address] == value, "write-through backing memory update");
            @(negedge clk);
            req_valid = 1'b0;
            req_wr_en = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        req_valid = 1'b0;
        req_addr = 8'h00;
        req_wr_en = 1'b0;
        req_wdata = 8'h00;
        checks = 0;
        for (n = 0; n < 256; n = n + 1)
            memory[n] = n ^ 8'hA5;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // First address maps to set 0 and fills Way 0 on a cold miss.
        read_byte(8'h04, 1'b0, (8'h04 ^ 8'hA5), "cold read miss");
        read_byte(8'h04, 1'b1, (8'h04 ^ 8'hA5), "repeated read hit");
        check(dut.hit_way0, "first allocation is found in Way 0");

        // Same set (address[1:0] == 0), different tag: fills Way 1.
        read_byte(8'h08, 1'b0, (8'h08 ^ 8'hA5), "second tag in same set");
        check(dut.hit_way1, "second allocation is found in Way 1");
        read_byte(8'h04, 1'b1, (8'h04 ^ 8'hA5), "Way 0 hit after second fill");
        read_byte(8'h08, 1'b1, (8'h08 ^ 8'hA5), "Way 1 hit and data selection");

        write_byte(8'h08, 8'h3C, 1'b1);
        read_byte(8'h08, 1'b1, 8'h3C, "write hit updates cached byte");

        // Reset invalidates both ways; a subsequent request must miss.
        @(negedge clk);
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        read_byte(8'h04, 1'b0, (8'h04 ^ 8'hA5), "reset invalidation");

        $display("PASS: all %0d cache_2way checks completed", checks);
        $finish;
    end
endmodule

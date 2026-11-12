// =============================================================================
// Module: cache_2way
// 4-set, 2-way set-associative byte cache with write-through/no-write-allocate.
// Address format: [7:2] tag, [1:0] set, no block offset.
// Interface: docs/INTERFACE_SPECIFICATION.md
// =============================================================================

module cache_2way (
    input  wire       clk,
    input  wire       rst_n,
    // CPU / master interface
    input  wire       req_valid,
    input  wire [7:0] req_addr,
    input  wire       req_wr_en,
    input  wire [7:0] req_wdata,
    output wire [7:0] resp_rdata,
    output wire       resp_valid,
    output wire       cache_hit,
    output wire       busy,
    // Backing memory interface
    output wire       mem_req,
    output wire       mem_wr_en,
    output wire [7:0] mem_addr,
    output wire [7:0] mem_wdata,
    input  wire [7:0] mem_rdata,
    input  wire       mem_ready
);

    localparam [1:0] STATE_IDLE       = 2'b00;
    localparam [1:0] STATE_READ_WAIT  = 2'b01;
    localparam [1:0] STATE_WRITE_WAIT = 2'b10;

    reg [1:0] state;

    // Each way stores four independent one-byte lines.
    reg [7:0] way0_data [0:3];
    reg [7:0] way1_data [0:3];
    reg [5:0] way0_tag  [0:3];
    reg [5:0] way1_tag  [0:3];
    reg       way0_valid[0:3];
    reg       way1_valid[0:3];

    reg [7:0] latched_addr;
    reg [7:0] latched_wdata;
    reg       latched_hit;

    wire [1:0] req_set = req_addr[1:0];
    wire [5:0] req_tag = req_addr[7:2];
    wire       hit_way0 = way0_valid[req_set] && (way0_tag[req_set] == req_tag);
    wire       hit_way1 = way1_valid[req_set] && (way1_tag[req_set] == req_tag);
    wire       hit_comb = hit_way0 || hit_way1;

    wire [1:0] lru_set;
    wire       lru_access_valid;
    wire       lru_access_way;
    wire       lru_way0_valid;
    wire       lru_way1_valid;
    wire       lru_victim_way;
    wire [3:0] lru_state_all;

    wire [1:0] refill_set = latched_addr[1:0];
    wire       refill_way;
    integer i;

    // Prefer an invalid way. When the set is full, Shitanshu's LRU controller
    // supplies the victim way (0 replaces Way 0; 1 replaces Way 1).
    assign refill_way = !way0_valid[refill_set] ? 1'b0 :
                        !way1_valid[refill_set] ? 1'b1 : lru_victim_way;

    assign lru_set = (state == STATE_READ_WAIT && mem_ready) ? refill_set : req_set;
    assign lru_access_valid = (state == STATE_READ_WAIT && mem_ready) ||
                               (state == STATE_IDLE && req_valid && hit_comb);
    assign lru_access_way = (state == STATE_READ_WAIT && mem_ready) ? refill_way : hit_way1;
    assign lru_way0_valid = (state == STATE_READ_WAIT) ? way0_valid[refill_set] : way0_valid[req_set];
    assign lru_way1_valid = (state == STATE_READ_WAIT) ? way1_valid[refill_set] : way1_valid[req_set];

    // LRU is owned by Shitanshu. This instance uses the agreed interface and
    // only receives access/refill status from the cache datapath.
    lru_controller lru (
        .clk           (clk),
        .rst_n         (rst_n),
        .set_index     (lru_set),
        .access_valid  (lru_access_valid),
        .access_way    (lru_access_way),
        .way0_valid    (lru_way0_valid),
        .way1_valid    (lru_way1_valid),
        .victim_way    (lru_victim_way),
        .lru_state_all (lru_state_all)
    );

    // A read hit completes in the lookup cycle. Memory transactions complete
    // only when the backing memory raises mem_ready.
    assign resp_valid = (state == STATE_IDLE && req_valid && !req_wr_en && hit_comb) ||
                        ((state == STATE_READ_WAIT || state == STATE_WRITE_WAIT) && mem_ready);

    assign resp_rdata = (state == STATE_IDLE && req_valid && !req_wr_en && hit_way0) ? way0_data[req_set] :
                        (state == STATE_IDLE && req_valid && !req_wr_en && hit_way1) ? way1_data[req_set] :
                        (state == STATE_READ_WAIT && mem_ready) ? mem_rdata : 8'h00;

    assign cache_hit = (state == STATE_IDLE && req_valid) ? hit_comb :
                       (state == STATE_WRITE_WAIT) ? latched_hit : 1'b0;

    assign busy = (state == STATE_READ_WAIT && !mem_ready) ||
                  (state == STATE_WRITE_WAIT && !mem_ready) ||
                  (state == STATE_IDLE && req_valid && (req_wr_en || !hit_comb));

    assign mem_req = (state == STATE_READ_WAIT) ||
                     (state == STATE_WRITE_WAIT) ||
                     (state == STATE_IDLE && req_valid && (req_wr_en || !hit_comb));
    assign mem_wr_en = (state == STATE_IDLE) ? req_wr_en : (state == STATE_WRITE_WAIT);
    assign mem_addr = (state == STATE_IDLE) ? req_addr : latched_addr;
    assign mem_wdata = (state == STATE_IDLE) ? req_wdata : latched_wdata;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= STATE_IDLE;
            latched_addr  <= 8'h00;
            latched_wdata <= 8'h00;
            latched_hit   <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                way0_valid[i] <= 1'b0;
                way1_valid[i] <= 1'b0;
                way0_tag[i]   <= 6'h00;
                way1_tag[i]   <= 6'h00;
                way0_data[i]  <= 8'h00;
                way1_data[i]  <= 8'h00;
            end
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (req_valid) begin
                        if (req_wr_en) begin
                            // Write-through; update cached data only on a hit.
                            latched_addr  <= req_addr;
                            latched_wdata <= req_wdata;
                            latched_hit   <= hit_comb;
                            if (hit_way0)
                                way0_data[req_set] <= req_wdata;
                            else if (hit_way1)
                                way1_data[req_set] <= req_wdata;
                            state <= STATE_WRITE_WAIT;
                        end else if (!hit_comb) begin
                            latched_addr <= req_addr;
                            state        <= STATE_READ_WAIT;
                        end
                    end
                end

                STATE_READ_WAIT: begin
                    if (mem_ready) begin
                        if (refill_way == 1'b0) begin
                            way0_tag[refill_set]   <= latched_addr[7:2];
                            way0_data[refill_set]  <= mem_rdata;
                            way0_valid[refill_set] <= 1'b1;
                        end else begin
                            way1_tag[refill_set]   <= latched_addr[7:2];
                            way1_data[refill_set]  <= mem_rdata;
                            way1_valid[refill_set] <= 1'b1;
                        end
                        state <= STATE_IDLE;
                    end
                end

                STATE_WRITE_WAIT: begin
                    if (mem_ready)
                        state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule

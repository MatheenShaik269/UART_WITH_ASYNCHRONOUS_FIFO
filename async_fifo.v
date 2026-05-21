`timescale 1ns/1ps

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    // =========================
    // WRITE DOMAIN
    // =========================
    input  wire                  clk_w,
    input  wire                  rst_w,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] data_in,
    output wire                  full,

    // =========================
    // READ DOMAIN
    // =========================
    input  wire                  clk_r,
    input  wire                  rst_r,
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] data_out,
    output reg                   data_valid,   
    output wire                  empty
);

    // =========================================================
    // MEMORY
    // =========================================================
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // =========================================================
    // POINTERS (Binary + Gray)
    // =========================================================
    reg [ADDR_WIDTH:0] w_ptr_bin, w_ptr_bin_next;
    reg [ADDR_WIDTH:0] r_ptr_bin, r_ptr_bin_next;

    reg [ADDR_WIDTH:0] w_ptr_gray, w_ptr_gray_next;
    reg [ADDR_WIDTH:0] r_ptr_gray, r_ptr_gray_next;

    // =========================================================
    // SYNCHRONIZERS
    // =========================================================

    // Read pointer → Write domain
    reg [ADDR_WIDTH:0] rptr_wclk_sync1, rptr_wclk_sync2;

    always @(posedge clk_w or posedge rst_w) begin
        if (rst_w) begin
            rptr_wclk_sync1 <= 0;
            rptr_wclk_sync2 <= 0;
        end else begin
            rptr_wclk_sync1 <= r_ptr_gray;
            rptr_wclk_sync2 <= rptr_wclk_sync1;
        end
    end

    // Write pointer → Read domain
    reg [ADDR_WIDTH:0] wptr_rclk_sync1, wptr_rclk_sync2;

    always @(posedge clk_r or posedge rst_r) begin
        if (rst_r) begin
            wptr_rclk_sync1 <= 0;
            wptr_rclk_sync2 <= 0;
        end else begin
            wptr_rclk_sync1 <= w_ptr_gray;
            wptr_rclk_sync2 <= wptr_rclk_sync1;
        end
    end

    // =========================================================
    // WRITE LOGIC
    // =========================================================
    always @(*) begin
        w_ptr_bin_next = w_ptr_bin;
        if (wr_en && !full)
            w_ptr_bin_next = w_ptr_bin + 1;

        w_ptr_gray_next = (w_ptr_bin_next >> 1) ^ w_ptr_bin_next;
    end

    always @(posedge clk_w or posedge rst_w) begin
        if (rst_w) begin
            w_ptr_bin  <= 0;
            w_ptr_gray <= 0;
        end else begin
            w_ptr_bin  <= w_ptr_bin_next;
            w_ptr_gray <= w_ptr_gray_next;
        end
    end

    always @(posedge clk_w) begin
        if (wr_en && !full)
            mem[w_ptr_bin[ADDR_WIDTH-1:0]] <= data_in;
    end

    // =========================================================
    // READ LOGIC
    // =========================================================
    always @(*) begin
        r_ptr_bin_next = r_ptr_bin;
        if (rd_en && !empty)
            r_ptr_bin_next = r_ptr_bin + 1;

        r_ptr_gray_next = (r_ptr_bin_next >> 1) ^ r_ptr_bin_next;
    end

    always @(posedge clk_r or posedge rst_r) begin
        if (rst_r) begin
            r_ptr_bin   <= 0;
            r_ptr_gray  <= 0;
            data_out    <= 0;   
            data_valid  <= 0;   
        end else begin
            r_ptr_bin  <= r_ptr_bin_next;
            r_ptr_gray <= r_ptr_gray_next;

            // VALID SIGNAL GENERATION
            if (rd_en && !empty) begin
                data_out   <= mem[r_ptr_bin[ADDR_WIDTH-1:0]];
                data_valid <= 1;
            end else begin
                data_valid <= 0;
            end
        end
    end

    // =========================================================
    // EMPTY FLAG
    // =========================================================
    assign empty = (r_ptr_gray == wptr_rclk_sync2);

    // =========================================================
    // FULL FLAG
    // =========================================================
    assign full = (w_ptr_gray ==
                   {~rptr_wclk_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
                     rptr_wclk_sync2[ADDR_WIDTH-2:0]});

endmodule

`timescale 1ns/1ps

module uart_top #(
    parameter CLK_FREQ        = 50000000,
    parameter BAUD_RATE       = 9600,
    parameter PARITY_ENABLE   = 1,
    parameter PARITY_TYPE     = 0,
    parameter FIFO_ADDR_WIDTH = 4
)(
    input  wire clk,
    input  wire rst,

    input  wire rx,
    output wire tx,

    input  wire tx_start,
    input  wire [7:0] tx_data,
    output wire tx_busy,

    input  wire rx_fifo_rd_en,
    output wire [7:0] rx_fifo_data_out,
    output wire rx_fifo_data_valid,
    output wire rx_fifo_empty,
    output wire rx_fifo_full,

    output wire rx_parity_error,
    output wire rx_framing_error
);

    // =========================================================
    // BAUD GENERATOR
    // =========================================================
    wire baud_tick;
    wire baud_16x_tick;

    baud_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_baud (
        .clk(clk),
        .rst(rst),
        .baud_tick(baud_tick),
        .baud_16x_tick(baud_16x_tick)
    );

    // =========================================================
    // UART TX
    // =========================================================
    uart_tx u_tx (
        .clk(clk),
        .rst(rst),
        .baud_tick(baud_tick),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .parity_enable(PARITY_ENABLE),
        .parity_type(PARITY_TYPE),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    // =========================================================
    // UART RX (raw receiver)
    // =========================================================
    wire [7:0] rx_data_raw;
    wire rx_valid;

    uart_rx u_rx (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tick_16x(baud_16x_tick),
        .parity_enable(PARITY_ENABLE),
        .parity_type(PARITY_TYPE),
        .rx_data(rx_data_raw),
        .rx_valid(rx_valid),
        .parity_error(rx_parity_error),
        .framing_error(rx_framing_error)
    );

    // =========================================================
    // RX FIFO WRITE DOMAIN
    // =========================================================
    async_fifo #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) u_fifo (
        // WRITE DOMAIN (RX side)
        .clk_w(clk),
        .rst_w(rst),
        .wr_en(rx_valid),
        .data_in(rx_data_raw),
        .full(rx_fifo_full),

        // READ DOMAIN (user side)
        .clk_r(clk),
        .rst_r(rst),
        .rd_en(rx_fifo_rd_en),
        .data_out(rx_fifo_data_out),
        .data_valid(rx_fifo_data_valid),
        .empty(rx_fifo_empty)
    );

endmodule
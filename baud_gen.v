`timescale 1ns/1ps

module baud_gen #(
    parameter CLK_FREQ = 50000000,   // 50 MHz
    parameter BAUD_RATE = 9600
)(
    input clk,
    input rst,
    output reg baud_tick,
    output reg baud_16x_tick
);

    // Calculate divisor
    localparam integer DIVISOR = CLK_FREQ / (BAUD_RATE * 16);

    reg [15:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            baud_tick <= 0;
            baud_16x_tick <= 0;
        end else begin
            if (count == DIVISOR - 1) begin
                count <= 0;
                baud_16x_tick <= 1;
            end else begin
                count <= count + 1;
                baud_16x_tick <= 0;
            end
        end
    end

    // Generate baud_tick (divide 16x tick)
    reg [3:0] tick_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tick_count <= 0;
            baud_tick <= 0;
        end else begin
            if (baud_16x_tick) begin
                if (tick_count == 15) begin
                    tick_count <= 0;
                    baud_tick <= 1;
                end else begin
                    tick_count <= tick_count + 1;
                    baud_tick <= 0;
                end
            end else begin
                baud_tick <= 0;
            end
        end
    end

endmodule
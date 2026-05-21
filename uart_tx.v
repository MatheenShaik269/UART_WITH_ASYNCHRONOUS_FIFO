`timescale 1ns/1ps

module uart_tx (
    input clk,
    input rst,
    input baud_tick,
    input tx_start,
    input [7:0] tx_data,
    input parity_enable,
    input parity_type,

    output reg tx,
    output reg tx_busy
);

    reg [3:0] bit_cnt;
    reg [10:0] shift_reg;
    reg [3:0] total_bits;

    wire parity_bit;

    // parity calculation
    assign parity_bit = (parity_type == 0) ? (^tx_data) : ~(^tx_data);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx <= 1'b1;
            tx_busy <= 0;
            bit_cnt <= 0;
            shift_reg <= 0;
            total_bits <= 0;
        end else begin

            // =========================
            // START TRANSMISSION
            // =========================
            if (tx_start && !tx_busy) begin
                tx_busy <= 1;

                if (parity_enable) begin
                    // start + 8 data + parity + stop = 11 bits
                    shift_reg <= {1'b1, parity_bit, tx_data, 1'b0};
                    total_bits <= 11;
                end else begin
                    // start + 8 data + stop = 10 bits
                    shift_reg <= {1'b1, tx_data, 1'b0};
                    total_bits <= 10;
                end

                bit_cnt <= 0;
            end

            // =========================
            // SHIFT ON BAUD TICK
            // =========================
            else if (tx_busy && baud_tick) begin

                tx <= shift_reg[0];           // output LSB
                shift_reg <= shift_reg >> 1;  // shift right
                bit_cnt <= bit_cnt + 1;

                if (bit_cnt == total_bits - 1) begin
                    tx_busy <= 0;
                    tx <= 1'b1; // idle
                end
            end
        end
    end

endmodule
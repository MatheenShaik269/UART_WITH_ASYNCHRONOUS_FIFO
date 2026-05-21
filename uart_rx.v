`timescale 1ns/1ps

module uart_rx (
    input clk,
    input rst,
    input rx,
    input tick_16x,

    input parity_enable,
    input parity_type, // 0=even, 1=odd

    output reg [7:0] rx_data,
    output reg rx_valid,

    output reg parity_error,
    output reg framing_error
);

    // ============================================================
    // STATES
    // ============================================================
    localparam IDLE  = 0,
               START = 1,
               DATA  = 2,
               PARITY= 3,
               STOP  = 4;

    reg [2:0] state;

    // ============================================================
    // SYNCHRONIZER (CDC SAFE)
    // ============================================================
    reg rx_sync1, rx_sync2;

    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end

    // ============================================================
    // SAMPLING CONTROL
    // ============================================================
    reg [3:0] sample_cnt;
    reg [2:0] bit_cnt;

    reg [7:0] shift_reg;
    reg parity_calc;

    // ============================================================
    // 3-POINT MAJORITY SAMPLING
    // ============================================================
    reg s1, s2, s3;

    wire sample_bit = (s1 & s2) | (s2 & s3) | (s1 & s3);

    always @(posedge clk) begin
        if (tick_16x) begin
            if (sample_cnt == 7) s1 <= rx_sync2;
            if (sample_cnt == 8) s2 <= rx_sync2;
            if (sample_cnt == 9) s3 <= rx_sync2;
        end
    end

    // ============================================================
    // MAIN FSM
    // ============================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            rx_data <= 0;
            rx_valid <= 0;

            parity_error <= 0;
            framing_error <= 0;

            sample_cnt <= 0;
            bit_cnt <= 0;
            shift_reg <= 0;
            parity_calc <= 0;

        end else begin

            rx_valid <= 0; // pulse

            if (tick_16x) begin

                case (state)

                // ====================================================
                // IDLE (WAIT FOR START)
                // ====================================================
                IDLE: begin
                    if (rx_sync2 == 0) begin
                        state <= START;
                        sample_cnt <= 0;
                    end
                end

                // ====================================================
                // START VALIDATION
                // ====================================================
                START: begin
                    sample_cnt <= sample_cnt + 1;

                    if (sample_cnt == 8) begin
                        if (rx_sync2 == 0) begin
                            state <= DATA;
                            sample_cnt <= 0;
                            bit_cnt <= 0;
                            parity_calc <= 0;
                            parity_error <= 0;
                            framing_error <= 0;
                        end else begin
                            state <= IDLE; // false start
                        end
                    end
                end

                // ====================================================
                // DATA BITS
                // ====================================================
                DATA: begin
                    sample_cnt <= sample_cnt + 1;

                    if (sample_cnt == 15) begin
                        sample_cnt <= 0;

                        shift_reg <= {sample_bit, shift_reg[7:1]};
                        parity_calc <= parity_calc ^ sample_bit;

                        if (bit_cnt == 7) begin
                            if (parity_enable)
                                state <= PARITY;
                            else
                                state <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end

                // ====================================================
                // PARITY
                // ====================================================
                PARITY: begin
                    sample_cnt <= sample_cnt + 1;

                    if (sample_cnt == 15) begin
                        sample_cnt <= 0;

                        if (parity_type == 0)
                            parity_error <= (parity_calc != sample_bit); // EVEN
                        else
                            parity_error <= (parity_calc == sample_bit); // ODD

                        state <= STOP;
                    end
                end

                // ====================================================
                // STOP BIT
                // ====================================================
                STOP: begin
                    sample_cnt <= sample_cnt + 1;

                    if (sample_cnt == 15) begin
                        sample_cnt <= 0;

                        // Direct sampling for reliability
                        framing_error <= (rx_sync2 != 1'b1);

                        rx_data <= shift_reg;
                        rx_valid <= 1;

                        state <= IDLE;
                    end
                end

                endcase
            end
        end
    end

endmodule
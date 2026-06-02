`timescale 1ns/1ps

module uart_top_tb;

    // ============================================================
    // PARAMETERS
    // ============================================================
    localparam CLK_PERIOD = 20;
    localparam BAUD_RATE  = 9600;
    localparam BIT_PERIOD = 1000000000 / BAUD_RATE;

    // ============================================================
    // DUT SIGNALS
    // ============================================================
    reg  clk;
    reg  rst;

    wire rx;
    wire tx;

    reg  tx_start;
    reg  [7:0] tx_data;
    wire tx_busy;

    reg  rx_fifo_rd_en;
    wire [7:0] rx_fifo_data_out;
    wire rx_fifo_data_valid;
    wire rx_fifo_empty;
    wire rx_fifo_full;

    wire rx_parity_error;
    wire rx_framing_error;

    // ============================================================
    // CONTROL
    // ============================================================
    reg loopback_en;
    reg rx_driver;

    reg rx_loop;
    always @(posedge clk) rx_loop <= tx;

    assign rx = loopback_en ? rx_loop : rx_driver;

    // ============================================================
    // TEST VARS
    // ============================================================
    integer test1_pass, test2_pass, test3_pass;
    integer test4_pass, test5_pass, test6_pass;

    integer test3_errors;
    reg [7:0] received_byte;

    // ============================================================
    // CLOCK
    // ============================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ============================================================
    // DUT
    // ============================================================
    uart_top #(
        .CLK_FREQ        (50_000_000),
        .BAUD_RATE       (BAUD_RATE),
        .PARITY_ENABLE   (1),
        .PARITY_TYPE     (0), // EVEN
        .FIFO_ADDR_WIDTH (4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx(tx),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .rx_fifo_rd_en(rx_fifo_rd_en),
        .rx_fifo_data_out(rx_fifo_data_out),
        .rx_fifo_data_valid(rx_fifo_data_valid),
        .rx_fifo_empty(rx_fifo_empty),
        .rx_fifo_full(rx_fifo_full),
        .rx_parity_error(rx_parity_error),
        .rx_framing_error(rx_framing_error)
    );

    // ============================================================
    // TASKS
    // ============================================================

    // TX SEND
    task send_byte_tx(input [7:0] data);
    begin
        @(posedge clk);
        tx_data  = data;
        tx_start = 1;

        @(posedge clk);
        tx_start = 0;

        wait(tx_busy == 0);
        repeat(2000) @(posedge clk);
    end
    endtask

    // FIFO READ
    task read_fifo(output [7:0] data);
    begin
        @(posedge clk);
        rx_fifo_rd_en = 1;
        @(posedge clk);
        data = rx_fifo_data_out;
        rx_fifo_rd_en = 0;
    end
    endtask

    task wait_fifo_not_empty;
    begin
        while (rx_fifo_empty)
            @(posedge clk);
    end
    endtask

    // ============================================================
    // RX GENERATOR (CORRECT FRAME)
    // ============================================================
    task generate_rx_byte(input [7:0] data);
        integer j;
        reg parity;
    begin
        parity = ^data;

        rx_driver = 0; #(BIT_PERIOD);

        for (j = 0; j < 8; j = j + 1) begin
            rx_driver = data[j];
            #(BIT_PERIOD);
        end

        rx_driver = parity; #(BIT_PERIOD);
        rx_driver = 1; #(BIT_PERIOD);
    end
    endtask

    // ============================================================
    // PARITY ERROR GENERATOR
    // ============================================================
    task generate_rx_byte_bad_parity(input [7:0] data);
        integer j;
        reg parity;
    begin
        parity = ~(^data); // wrong parity

        rx_driver = 0; #(BIT_PERIOD);

        for (j = 0; j < 8; j = j + 1) begin
            rx_driver = data[j];
            #(BIT_PERIOD);
        end

        rx_driver = parity; #(BIT_PERIOD);
        rx_driver = 1; #(BIT_PERIOD);
    end
    endtask

    // ============================================================
    // FRAMING ERROR GENERATOR (FIXED)
    // ============================================================
    task generate_rx_byte_bad_stop(input [7:0] data);
        integer j;
        reg parity;
    begin
        parity = ^data;

        rx_driver = 0; #(BIT_PERIOD);

        for (j = 0; j < 8; j = j + 1) begin
            rx_driver = data[j];
            #(BIT_PERIOD);
        end

        rx_driver = parity; #(BIT_PERIOD);

        //  WRONG STOP BIT
        rx_driver = 0; #(BIT_PERIOD);

        // back to idle
        rx_driver = 1; #(BIT_PERIOD);
    end
    endtask

    // ============================================================
    // CHECK BYTE
    // ============================================================
    task check_byte(input [7:0] exp);
    begin
        wait_fifo_not_empty();
        read_fifo(received_byte);

        if (received_byte != exp) begin
            test3_errors = test3_errors + 1;
            $display("ERROR: expected %h got %h", exp, received_byte);
        end
    end
    endtask

    // ============================================================
    // MAIN TEST
    // ============================================================
    initial begin

        rst = 1;
        tx_start = 0;
        tx_data  = 0;
        rx_fifo_rd_en = 0;
        loopback_en = 0;
        rx_driver = 1;

        test3_errors = 0;

        repeat(10) @(posedge clk);
        rst = 0;
        repeat(10) @(posedge clk);

        $display("\n=========== UART TEST ===========");

        // TEST 1
        loopback_en = 1;
        send_byte_tx(8'hA5);
        wait_fifo_not_empty();
        read_fifo(received_byte);
        test1_pass = (received_byte == 8'hA5);
        loopback_en = 0;

        // TEST 2
        generate_rx_byte(8'h3C);
        wait_fifo_not_empty();
        read_fifo(received_byte);
        test2_pass = (received_byte == 8'h3C);

        // TEST 3
        generate_rx_byte(8'h12); #(BIT_PERIOD);
        generate_rx_byte(8'h34); #(BIT_PERIOD);
        generate_rx_byte(8'h56); #(BIT_PERIOD);
        generate_rx_byte(8'h78); #(BIT_PERIOD);

        repeat(5000) @(posedge clk);

        check_byte(8'h12);
        check_byte(8'h34);
        check_byte(8'h56);
        check_byte(8'h78);

        test3_pass = (test3_errors == 0);

        // TEST 4
        loopback_en = 1;
        send_byte_tx(8'hAA);
        send_byte_tx(8'h55);
        test4_pass = 1;
        loopback_en = 0;

        // TEST 5
        generate_rx_byte_bad_parity(8'hA5);
        repeat(2000) @(posedge clk);
        test5_pass = rx_parity_error;

        // TEST 6 (FIXED)
        generate_rx_byte_bad_stop(8'hA5);
        repeat(2000) @(posedge clk);
        test6_pass = rx_framing_error;

        // FINAL REPORT
        $display("\n=========== FINAL REPORT ===========");
        $display("TEST1: %s", test1_pass ? "PASS" : "FAIL");
        $display("TEST2: %s", test2_pass ? "PASS" : "FAIL");
        $display("TEST3: %s", test3_pass ? "PASS" : "FAIL");
        $display("TEST4: %s", test4_pass ? "PASS" : "FAIL");
        $display("TEST5: %s", test5_pass ? "PASS" : "FAIL");
        $display("TEST6: %s", test6_pass ? "PASS" : "FAIL");

        if (test1_pass && test2_pass && test3_pass &&
            test4_pass && test5_pass && test6_pass)
            $display("\n>>>> ALL TESTS PASSED <<<<");
        else
            $display("\n>>>> SOME TESTS FAILED <<<<");

        $finish;
    end

endmodule
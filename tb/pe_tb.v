`timescale 1ns/1ps

module pe_tb;
    parameter DATA_WIDTH = 32;
    parameter INPUT_WIDTH = 8;
    parameter CLK_PERIOD = 10;

    reg clk;
    reg rst;
    reg load_kernel_signal;
    reg [INPUT_WIDTH-1:0] in_top;
    reg [INPUT_WIDTH-1:0] in_left;
    wire [DATA_WIDTH-1:0] out_partial;
    wire [INPUT_WIDTH-1:0] out_down;
    wire [INPUT_WIDTH-1:0] out_right;

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) uut (
        .clk(clk),
        .rst(rst),
        .load_kernel_signal(load_kernel_signal),
        .in_top(in_top),
        .in_left(in_left),
        .out_partial(out_partial),
        .out_down(out_down),
        .out_right(out_right)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    task check_result;
        input [DATA_WIDTH-1:0] expected_partial;
        input [INPUT_WIDTH-1:0] expected_down;
        input [INPUT_WIDTH-1:0] expected_right;
        input [8*50:1] test_name;
        begin
            test_count = test_count + 1;
            if (out_partial == expected_partial && out_down == expected_down && out_right == expected_right) begin
                $display("PASS: %s - Expected: partial = %0d, down = %0d, right = %0d | Got: partial = %0d, down = %0d, right = %0d",
                test_name, expected_partial, expected_down, expected_right, out_partial, out_down, out_right);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %s - Expected: partial = %0d, down = %0d, right = %0d | Got: partial = %0d, down = %0d, right = %0d",
                test_name, expected_partial, expected_down, expected_right, out_partial, out_down, out_right);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        rst                = 1;
        load_kernel_signal = 0;
        in_top             = 0;
        in_left            = 0;

        #(CLK_PERIOD * 2);

        rst = 0;
        #(CLK_PERIOD);

        // Test 1: Basic multiplication (5 * 3 = 15)
        in_top             = 8'd5;
        in_left            = 8'd3;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        check_result(32'd15, 8'd5, 8'd3, "Basic multiplication 5*3");

        // Test 2: Zero multiplication
        in_top             = 8'd0;
        in_left            = 8'd15;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        check_result(32'd0, 8'd0, 8'd15, "Zero multiplication 15*0");

        // Test 3: Max 8-bit values (255 * 255 = 65025)
        in_top             = 8'd255;
        in_left            = 8'd255;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        check_result(32'd65025, 8'd255, 8'd255, "Max values 255*255");

        // Test 4: Reset during operation
        in_top = 8'd100;
        in_left = 8'd200;
        load_kernel_signal = 1;
        #(CLK_PERIOD/2); // sometime to load kernel and compute

        // Interrupt mid-operation
        rst = 1;
        #(CLK_PERIOD);
        rst = 0;

        // Inputs cleared
        load_kernel_signal = 0;
        in_top = 0;
        in_left = 0;

        #(CLK_PERIOD);
        check_result(32'd0, 8'd0, 8'd0, "Reset during operation");

        // Test 5: Load new kernel after reset (50 * 60 = 3000)
        in_top             = 8'd50;
        in_left            = 8'd60;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        check_result(32'd3000, 8'd50, 8'd60, "Multiplication after reset 60*50");

        // Test 6: Load new kernel
        in_top             = 8'd10;
        in_left            = 8'd99;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        check_result(32'd990, 8'd10, 8'd99, "New kernel calculation 99*10");

        // Test 7: Single value tests
        in_top             = 8'd1;
        in_left            = 8'd123;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        check_result(32'd123, 8'd1, 8'd123, "Multiplication by 1: 123*1");

        // Test 8: Small values 9*9
        in_top             = 8'd9;
        in_left            = 8'd9;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        check_result(32'd81, 8'd9, 8'd9, "Single digit 9*9");

        $display("Test Summary:");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED! ✗");
        end

        $display("Testbench completed!");
        #(CLK_PERIOD * 2);
        $finish;
    end

    initial begin
        $dumpfile("pe_testbench.vcd");
        $dumpvars(0, pe_tb);
    end

endmodule

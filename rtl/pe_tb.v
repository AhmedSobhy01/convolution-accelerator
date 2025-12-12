`timescale 1ns/1ps

module pe_tb;
    // Parameters
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 10ns clock period (100MHz)

    // Testbench signals
    reg clk;
    reg rst;
    reg load_kernel_signal;
    reg [DATA_WIDTH-1:0] in_top;
    reg [DATA_WIDTH-1:0] in_left;
    wire [DATA_WIDTH-1:0] out_partial;
    wire [DATA_WIDTH-1:0] out_down;
    wire [DATA_WIDTH-1:0] out_right;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate the PE module
    pe #(.DATA_WIDTH(DATA_WIDTH)) uut (
        .clk(clk),
        .rst(rst),
        .load_kernel_signal(load_kernel_signal),
        .in_top(in_top),
        .in_left(in_left),
        .out_partial(out_partial),
        .out_down(out_down),
        .out_right(out_right)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Task to check test results
    task check_result;
        input [DATA_WIDTH-1:0] expected_partial;
        input [DATA_WIDTH-1:0] expected_down;
        input [DATA_WIDTH-1:0] expected_right;
        input [8*50:1] test_name;
        begin
            test_count = test_count + 1;
            if (out_partial == expected_partial && out_down == expected_down && out_right == expected_right) begin
                $display("PASS: %s - Expected: partial=%0d, down=%0d, right=%0d | Got: partial=%0d, down=%0d, right=%0d",
                         test_name, expected_partial, expected_down, expected_right, out_partial, out_down, out_right);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %s - Expected: partial=%0d, down=%0d, right=%0d | Got: partial=%0d, down=%0d, right=%0d",
                         test_name, expected_partial, expected_down, expected_right, out_partial, out_down, out_right);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Test stimulus
    initial begin
        // Initialize signals
        rst = 1;
        load_kernel_signal = 0;
        in_top = 0;
        in_left = 0;

        // Wait for a few clock cycles
        #(CLK_PERIOD * 2);

        // Release reset
        rst = 0;
        #(CLK_PERIOD);

        $display("Starting PE testbench with assertions...");
        $display("=====================================");

        // Test 1: Basic multiplication (5 * 3 = 15)
        in_top = 32'd5;
        in_left = 32'd3;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        check_result(32'd15, 32'd5, 32'd3, "Basic multiplication 5*3");

        // // Test 2: Another multiplication (10 * 7 = 70)
        // in_top = 32'd10;
        // in_left = 32'd7;
        // load_kernel_signal = 1;
        // #(CLK_PERIOD);
        // load_kernel_signal = 0;
        // #(CLK_PERIOD);
        // check_result(32'd70, 32'd10, 32'd7, "Multiplication 10*7");

        // Test 3: Zero multiplication (0 * 15 = 0)
        in_top = 32'd0;
        in_left = 32'd15;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        check_result(32'd0, 32'd0, 32'd15, "Zero multiplication 0*15");

        // Test 4: Large values (1000 * 2000 = 2000000)
        in_top = 32'd1000;
        in_left = 32'd2000;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        check_result(32'd2000000, 32'd1000, 32'd2000, "Large values 1000*2000");

        // Test 5: Reset during operation - should reset product to 0
        in_top = 32'd100;
        in_left = 32'd200;
        load_kernel_signal = 1;
        #(CLK_PERIOD/2);
        rst = 1;
        #(CLK_PERIOD);
        rst = 0;
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        check_result(32'd0, 32'd100, 32'd200, "Reset during operation");

        // Test 6: Load signal inactive - should keep previous product (0 from reset)
        in_top = 32'd50;
        in_left = 32'd60;
        load_kernel_signal = 0; // Keep load signal low
        #(CLK_PERIOD * 2);
        check_result(32'd0, 32'd50, 32'd60, "Load signal inactive");

        // Test 7: New multiplication after inactive load (50 * 60 = 3000)
        in_top = 32'd50;
        in_left = 32'd60;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        check_result(32'd3000, 32'd50, 32'd60, "Multiplication after inactive load 50*60");

        // Test 8: Pass-through verification with different values
        in_top = 32'd123;
        in_left = 32'd456;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        check_result(32'd56088, 32'd123, 32'd456, "Pass-through verification 123*456");

        // Test 9: Edge case - multiplication by 1
        in_top = 32'd1;
        in_left = 32'd999;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        check_result(32'd999, 32'd1, 32'd999, "Multiplication by 1: 1*999");

        // Test 10: Maximum single digit values
        in_top = 32'd9;
        in_left = 32'd9;
        load_kernel_signal = 1;
        #(CLK_PERIOD);
        load_kernel_signal = 0;
        #(CLK_PERIOD);
        check_result(32'd81, 32'd9, 32'd9, "Single digit max 9*9");

        // Display final results
        $display("=====================================");
        $display("Test Summary:");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED! ✓");
        end else begin
            $display("SOME TESTS FAILED! ✗");
        end

        $display("Testbench completed!");
        #(CLK_PERIOD * 2);
        $finish;
    end

    // Generate VCD file for waveform viewing
    // initial begin
    //     $dumpfile("pe_testbench.vcd");
    //     $dumpvars(0, pe_testbench);
    // end

endmodule

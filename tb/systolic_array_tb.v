`timescale 1ns/1ps

module systolic_array_tb;
    localparam integer DATA_WIDTH  = 32;
    localparam integer ARRAY_SIZE  = 3;
    localparam integer INPUT_WIDTH = 8;
    localparam integer INPUT_DEPTH = ARRAY_SIZE * ARRAY_SIZE;

    reg clk;
    reg rst;
    reg load_kernel_signal;
    reg [INPUT_WIDTH * ARRAY_SIZE - 1:0] input_in;
    reg [INPUT_WIDTH * ARRAY_SIZE - 1:0] kernel_in;
    wire [DATA_WIDTH-1:0] out_data;

    integer pass_count = 0;
    integer fail_count = 0;

    systolic_array #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .INPUT_WIDTH(INPUT_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .load_kernel_signal(load_kernel_signal),
        .input_in(input_in),
        .kernel_in(kernel_in),
        .out_data(out_data)
    );

    reg [INPUT_WIDTH * ARRAY_SIZE - 1:0] kernel_vectors [0:ARRAY_SIZE-1];
    reg [INPUT_WIDTH * ARRAY_SIZE - 1:0] input_vectors  [0:INPUT_DEPTH-1];

    reg [DATA_WIDTH-1:0] expected_outputs [0:INPUT_DEPTH-1];
    integer output_idx;
    reg outputs_valid;

    integer idx;

    initial begin
        clk            = 1'b0;
        forever #5 clk = ~clk;
    end

    task assert_equal;
        input [DATA_WIDTH-1:0] actual;
        input [DATA_WIDTH-1:0] expected;
        input [8*80:1] msg;
        begin
            if (actual === expected) begin
                $display("[PASS] %s: Expected=%0d, Got=%0d at time %0t", msg, expected, actual, $time);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s: Expected=%0d, Got=%0d at time %0t", msg, expected, actual, $time);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task assert_zero;
        input [DATA_WIDTH-1:0] value;
        input [8*80:1] msg;
        begin
            if (value === {DATA_WIDTH{1'b0}}) begin
                $display("[PASS] %s: Value is zero at time %0t", msg, $time);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s: Expected zero, Got=%0d at time %0t", msg, value, $time);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_output;
        input [DATA_WIDTH-1:0] expected;
        input [8*50:1] test_name;
        begin
            if (out_data == expected) begin
                $display("PASS: %s - Expected: %0d, Got: %0d", test_name, expected, out_data);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %s - Expected: %0d, Got: %0d", test_name, expected, out_data);
                fail_count = fail_count + 1;
            end
        end
    endtask


    // Test 1: Output should be zero during reset
    always @(posedge clk) begin
        if (rst) begin
            #1;
            if (out_data !== {DATA_WIDTH{1'b0}}) begin
                $display("[FAIL] Output should be zero during reset at time %0t, got %0d", $time, out_data);
                fail_count = fail_count + 1;
            end
        end
    end

    // Load kernel signal should only be high for ARRAY_SIZE cycles during kernel loading
    integer load_kernel_cycle_count;
    initial load_kernel_cycle_count = 0;

    always @(posedge clk) begin
        if (load_kernel_signal && !rst) begin
            load_kernel_cycle_count = load_kernel_cycle_count + 1;
        end
    end

    integer cycle_after_input_start;
    reg input_feeding_started;
    reg checking_outputs;
    integer expected_output_index;
    reg [DATA_WIDTH-1:0] captured_outputs [0:INPUT_DEPTH-1];
    integer capture_idx;

    initial begin
        cycle_after_input_start = 0;
        input_feeding_started = 1'b0;
        checking_outputs = 1'b0;
        expected_output_index = 0;
        capture_idx = 0;
    end

    localparam integer PIPELINE_DELAY = ARRAY_SIZE;

    // Capture outputs
    always @(negedge clk) begin
        if (!rst && outputs_valid) begin
            cycle_after_input_start = cycle_after_input_start + 1;

            if (cycle_after_input_start >= PIPELINE_DELAY && capture_idx < INPUT_DEPTH) begin
                captured_outputs[capture_idx] = out_data;
                capture_idx = capture_idx + 1;
            end
        end
    end

    initial begin
        kernel_vectors[0] = {8'd100, 8'd10, 8'd20}; // Column 0: {K[2][0], K[1][0], K[0][0]}
        kernel_vectors[1] = {8'd10, 8'd20, 8'd40};  // Column 1: {K[2][1], K[1][1], K[0][1]}
        kernel_vectors[2] = {8'd60, 8'd30, 8'd50};  // Column 2: {K[2][2], K[1][2], K[0][2]}

        input_vectors[0] = {8'd12, 8'd52, 8'd32}; // [12, 52, 32]
        input_vectors[1] = {8'd20, 8'd18, 8'd28}; // [20, 18, 28]
        input_vectors[2] = {8'd34, 8'd37, 8'd1}; // [34, 37, 1]
        input_vectors[3] = {8'd9, 8'd6, 8'd28}; // [9, 6, 28]
        input_vectors[4] = {8'd22, 8'd98, 8'd32}; // [22, 98, 32]
        input_vectors[5] = {8'd18, 8'd12, 8'd17}; // [18, 12, 17]
        input_vectors[6] = {8'd88, 8'd72, 8'd62}; // [88, 72, 62]
        input_vectors[7] = {8'd42, 8'd23, 8'd28}; // [42, 23, 28]
        input_vectors[8] = {8'd29, 8'd56, 8'd2}; // [29, 56, 2]

        expected_outputs[0] = 32'd9600;
        expected_outputs[1] = 32'd6600;
        expected_outputs[2] = 32'd7200;
        expected_outputs[3] = 32'd4300;
        expected_outputs[4] = 32'd15200;
        expected_outputs[5] = 32'd4700;
        expected_outputs[6] = 32'd22200;
        expected_outputs[7] = 32'd9300;
        expected_outputs[8] = 32'd8700;
    end

    initial begin
        $display("Starting Systolic Array Testbench");

        outputs_valid = 1'b0;
        output_idx    = 0;

        rst                = 1'b1;
        load_kernel_signal = 1'b0;
        input_in           = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};
        kernel_in          = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};

        repeat (3) @(posedge clk);
        assert_zero(out_data, "Output zero during reset");

        rst = 1'b0;

        @(posedge clk);

        load_kernel_signal = 1'b1;
        $display("Loading kernel weights...");

        for (idx = 0; idx < ARRAY_SIZE; idx = idx + 1) begin
            @(negedge clk);
            kernel_in = kernel_vectors[idx];
            $display("  Kernel row %0d: %h", idx, kernel_vectors[idx]);
            @(posedge clk);
        end

        @(negedge clk);
        load_kernel_signal = 1'b0;
        outputs_valid      = 1'b1;
        output_idx         = 0;
        input_in           = input_vectors[0];
        @(posedge clk);
        $display("Kernel loading complete at time %0t", $time);

        if (load_kernel_cycle_count == ARRAY_SIZE) begin
            $display("[PASS] Kernel loaded in exactly %0d cycles", ARRAY_SIZE);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Kernel load took %0d cycles, expected %0d", load_kernel_cycle_count, ARRAY_SIZE);
            fail_count = fail_count + 1;
        end

        $display("Feeding input data and checking outputs...");

        for (idx = 1; idx < INPUT_DEPTH; idx = idx + 1) begin
            @(negedge clk);
            input_in = input_vectors[idx];
            @(posedge clk);
        end

        input_in = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};
        repeat (PIPELINE_DELAY) @(posedge clk);

        // Check outputs
        $display("Verifying Captured Output Values:");
        for (idx = 0; idx < INPUT_DEPTH; idx = idx + 1) begin
            if (captured_outputs[idx] === expected_outputs[idx]) begin
                $display("PASS: Output[%0d] - Expected: %0d, Got: %0d", idx, expected_outputs[idx], captured_outputs[idx]);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: Output[%0d] - Expected: %0d, Got: %0d", idx, expected_outputs[idx], captured_outputs[idx]);
                fail_count = fail_count + 1;
            end
        end

        $display("---------------------------------------------------------");
        $display("Test Summary:");
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("---------------------------------------------------------");

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end

        $finish;
    end

    always @(posedge clk) begin
        $display("%0t | load = %0b input = %h kernel = %h -> out = %0d (0x%h)",
        $time, load_kernel_signal, input_in, kernel_in, out_data, out_data);
    end

    initial begin
        $dumpfile("systolic_array_tb.vcd");
        $dumpvars(0, systolic_array_tb);
    end
endmodule

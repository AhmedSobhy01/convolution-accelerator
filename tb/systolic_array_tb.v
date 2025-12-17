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

    systolic_array #(.DATA_WIDTH(DATA_WIDTH), .ARRAY_SIZE(ARRAY_SIZE), .INPUT_WIDTH(INPUT_WIDTH)) dut (
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

    integer current_test;
    reg [8*50:1] current_test_name;

    integer load_kernel_cycle_count;
    integer cycle_after_input_start;
    reg input_feeding_started;
    reg checking_outputs;
    integer expected_output_index;
    reg [DATA_WIDTH-1:0] captured_outputs [0:INPUT_DEPTH-1];
    integer capture_idx;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task do_reset;
        begin
            rst = 1'b1;
            load_kernel_signal = 1'b0;
            input_in = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};
            kernel_in = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};
            repeat (3) @(posedge clk);
            rst = 1'b0;
            @(posedge clk);
        end
    endtask

    task load_kernel;
        integer k;
        begin
            load_kernel_signal = 1'b1;
            for (k = 0; k < ARRAY_SIZE; k = k + 1) begin
                @(negedge clk);
                kernel_in = kernel_vectors[k];
                @(posedge clk);
            end
            @(negedge clk);
            load_kernel_signal = 1'b0;
        end
    endtask

    task run_convolution;
        integer i;
        begin
            outputs_valid = 1'b1;
            cycle_after_input_start = 0;
            capture_idx = 0;

            input_in = input_vectors[0];
            @(posedge clk);

            for (i = 1; i < INPUT_DEPTH; i = i + 1) begin
                @(negedge clk);
                input_in = input_vectors[i];
                @(posedge clk);
            end

            // flush pipeline
            for (i = 0; i < ARRAY_SIZE - 1; i = i + 1) begin
                @(negedge clk);
                input_in = input_vectors[INPUT_DEPTH - 1];
                @(posedge clk);
            end

            input_in = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};
            repeat (ARRAY_SIZE) @(posedge clk);
            outputs_valid = 1'b0;
        end
    endtask

    task verify_outputs;
        input [8*50:1] test_name;
        integer i;
        begin
            $display("Verifying outputs for: %s", test_name);
            for (i = 0; i < INPUT_DEPTH; i = i + 1) begin
                if (captured_outputs[i] === expected_outputs[i]) begin
                    $display("  PASS: Output[%0d] - Expected: %0d, Got: %0d", i, expected_outputs[i], captured_outputs[i]);
                    pass_count = pass_count + 1;
                end else begin
                    $display("  FAIL: Output[%0d] - Expected: %0d, Got: %0d", i, expected_outputs[i], captured_outputs[i]);
                    fail_count = fail_count + 1;
                end
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
    initial load_kernel_cycle_count = 0;

    always @(posedge clk) begin
        if (load_kernel_signal && !rst) begin
            load_kernel_cycle_count = load_kernel_cycle_count + 1;
        end
    end

    initial begin
        cycle_after_input_start = 0;
        input_feeding_started = 1'b0;
        checking_outputs = 1'b0;
        expected_output_index = 0;
        capture_idx = 0;
    end

    // Capture outputs
    always @(negedge clk) begin
        if (!rst && outputs_valid) begin
            cycle_after_input_start = cycle_after_input_start + 1;

            if (cycle_after_input_start >= ARRAY_SIZE && capture_idx < INPUT_DEPTH) begin
                captured_outputs[capture_idx] = out_data;
                capture_idx = capture_idx + 1;
            end
        end
    end

    initial begin
        outputs_valid = 1'b0;
        output_idx    = 0;
        current_test  = 0;

        // =========================================================
        // TEST 1: Basic Convolution Test
        // =========================================================
        $display("\n---------------------------------------------------------");
        $display("TEST 1: Basic Convolution Test");
        $display("---------------------------------------------------------");

        // Kernel
        // [20 40 50]
        // [10 20 30]
        // [100 10 60]
        kernel_vectors[0] = {8'd20, 8'd10, 8'd100};
        kernel_vectors[1] = {8'd40, 8'd20, 8'd10};
        kernel_vectors[2] = {8'd50, 8'd30, 8'd60};

        input_vectors[0] = {8'd12, 8'd52, 8'd32}; // [12, 52, 32]
        input_vectors[1] = {8'd20, 8'd18, 8'd28}; // [20, 18, 28]
        input_vectors[2] = {8'd34, 8'd37, 8'd1}; // [34, 37, 1]
        input_vectors[3] = {8'd9, 8'd6, 8'd28}; // [9, 6, 28]
        input_vectors[4] = {8'd22, 8'd98, 8'd32}; // [22, 98, 32]
        input_vectors[5] = {8'd18, 8'd12, 8'd17}; // [18, 12, 17]
        input_vectors[6] = {8'd88, 8'd72, 8'd62}; // [88, 72, 62]
        input_vectors[7] = {8'd42, 8'd23, 8'd28}; // [42, 23, 28]
        input_vectors[8] = {8'd29, 8'd56, 8'd2}; // [29, 56, 2]

        expected_outputs[0] = 32'd9150;
        expected_outputs[1] = 32'd6270;
        expected_outputs[2] = 32'd8360;
        expected_outputs[3] = 32'd7900;
        expected_outputs[4] = 32'd20130;
        expected_outputs[5] = 32'd11980;
        expected_outputs[6] = 32'd13040;
        expected_outputs[7] = 32'd4630;
        expected_outputs[8] = 32'd2920;

        rst                = 1'b1;
        load_kernel_signal = 1'b0;
        input_in           = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};
        kernel_in          = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};

        repeat (3) @(posedge clk);
        if (out_data === {DATA_WIDTH{1'b0}}) begin
            $display("[PASS] Output zero during reset at time %0t", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Output zero during reset: Expected zero, Got=%0d at time %0t", out_data, $time);
            fail_count = fail_count + 1;
        end

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
        repeat (ARRAY_SIZE) @(posedge clk);
        outputs_valid = 1'b0;

        verify_outputs("Basic Convolution");

        // =========================================================
        // TEST 2: All Zeros Input
        // =========================================================
        $display("\n---------------------------------------------------------");
        $display("TEST 2: All Zeros Input", current_test);
        $display("---------------------------------------------------------");

        do_reset();

        // put zero input but same kernel
        for (idx = 0; idx < INPUT_DEPTH; idx = idx + 1) begin
            input_vectors[idx] = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};
            expected_outputs[idx] = 32'd0;
        end

        load_kernel();
        run_convolution();
        verify_outputs("All Zeros Input");

        // =========================================================
        // TEST 3: All Zeros Kernel
        // =========================================================
        current_test = 3;
        $display("\n---------------------------------------------------------");
        $display("TEST %0d: All Zeros Kernel", current_test);
        $display("---------------------------------------------------------");

        do_reset();

        // Kernel
        // [0 0 0]
        // [0 0 0]
        // [0 0 0]
        kernel_vectors[0] = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};
        kernel_vectors[1] = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};
        kernel_vectors[2] = {(INPUT_WIDTH * ARRAY_SIZE){1'b0}};

        input_vectors[0] = {8'd255, 8'd255, 8'd255}; // [255, 255, 255]
        input_vectors[1] = {8'd128, 8'd128, 8'd128}; // [128, 128, 128]
        input_vectors[2] = {8'd64, 8'd64, 8'd64}; // [64, 64, 64]
        input_vectors[3] = {8'd32, 8'd32, 8'd32}; // [32, 32, 32]
        input_vectors[4] = {8'd16, 8'd16, 8'd16}; // [16, 16, 16]
        input_vectors[5] = {8'd8, 8'd8, 8'd8}; // [8, 8, 8]
        input_vectors[6] = {8'd4, 8'd4, 8'd4}; // [4, 4, 4]
        input_vectors[7] = {8'd2, 8'd2, 8'd2}; // [2, 2, 2]
        input_vectors[8] = {8'd1, 8'd1, 8'd1}; // [1, 1, 1]

        for (idx = 0; idx < INPUT_DEPTH; idx = idx + 1) begin
            expected_outputs[idx] = 32'd0;
        end

        load_kernel();
        run_convolution();
        verify_outputs("All Zeros Kernel");

        // =========================================================
        // TEST 4: All Ones Input and Kernel
        // =========================================================
        current_test = 4;
        $display("\n---------------------------------------------------------");
        $display("TEST %0d: All Ones Input and Kernel", current_test);
        $display("---------------------------------------------------------");

        do_reset();

        // Kernel
        // [1 1 1]
        // [1 1 1]
        // [1 1 1]
        kernel_vectors[0] = {8'd1, 8'd1, 8'd1};
        kernel_vectors[1] = {8'd1, 8'd1, 8'd1};
        kernel_vectors[2] = {8'd1, 8'd1, 8'd1};

        // All ones inputs
        for (idx = 0; idx < INPUT_DEPTH; idx = idx + 1) begin
            input_vectors[idx] = {8'd1, 8'd1, 8'd1};
            expected_outputs[idx] = 32'd9;
        end

        load_kernel();
        run_convolution();
        verify_outputs("All Ones");

        // =========================================================
        // TEST 5: Maximum Values (255)
        // =========================================================
        current_test = 5;
        $display("\n---------------------------------------------------------");
        $display("TEST %0d: Maximum Values (255)", current_test);
        $display("---------------------------------------------------------");

        do_reset();

        // Kernel
        // [255 255 255]
        // [255 255 255]
        // [255 255 255]
        kernel_vectors[0] = {8'd255, 8'd255, 8'd255};
        kernel_vectors[1] = {8'd255, 8'd255, 8'd255};
        kernel_vectors[2] = {8'd255, 8'd255, 8'd255};

        // Max value inputs
        for (idx = 0; idx < INPUT_DEPTH; idx = idx + 1) begin
            input_vectors[idx] = {8'd255, 8'd255, 8'd255};
            expected_outputs[idx] = 32'd585225;
        end

        load_kernel();
        run_convolution();
        verify_outputs("Maximum Values");

        // =========================================================
        // TEST 6: One in the center kernel
        // =========================================================
        current_test = 6;
        $display("\n---------------------------------------------------------");
        $display("TEST %0d: One in the center kernel", current_test);
        $display("---------------------------------------------------------");

        do_reset();

        // Kernel
        // [0 0 0]
        // [0 1 0]
        // [0 0 0]
        kernel_vectors[0] = {8'd0, 8'd0, 8'd0};
        kernel_vectors[1] = {8'd0, 8'd1, 8'd0};
        kernel_vectors[2] = {8'd0, 8'd0, 8'd0};

        for (idx = 0; idx < INPUT_DEPTH; idx = idx + 1) begin
            input_vectors[idx] = {8'd10, 8'd50, 8'd90};
            expected_outputs[idx] = 32'd50;
        end

        load_kernel();
        run_convolution();
        verify_outputs("One in the center kernel");

        // =========================================================
        // TEST 7: Reset During Operation
        // =========================================================
        current_test = 7;
        $display("\n---------------------------------------------------------");
        $display("TEST %0d: Reset During Operation", current_test);
        $display("---------------------------------------------------------");

        do_reset();

        // Kernel
        // [1 1 1]
        // [1 1 1]
        // [1 1 1]
        kernel_vectors[0] = {8'd1, 8'd1, 8'd1};
        kernel_vectors[1] = {8'd1, 8'd1, 8'd1};
        kernel_vectors[2] = {8'd1, 8'd1, 8'd1};

        load_kernel();

        input_in = {8'd10, 8'd10, 8'd10};
        @(posedge clk);
        @(posedge clk);

        rst = 1'b1;
        @(posedge clk);

        #1;
        if (out_data === {DATA_WIDTH{1'b0}}) begin
            $display("[PASS] Output correctly zeroed during mid-operation reset");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Output not zero during mid-operation reset, got %0d", out_data);
            fail_count = fail_count + 1;
        end

        rst = 1'b0;
        @(posedge clk);

        // =========================================================
        // TEST 8: Kernel after Kernel Load
        // =========================================================
        current_test = 8;
        $display("\n---------------------------------------------------------");
        $display("TEST %0d: Kernel after Kernel Load", current_test);
        $display("---------------------------------------------------------");

        do_reset();

        // First kernel
        // [1 1 1]
        // [1 1 1]
        // [1 1 1]
        kernel_vectors[0] = {8'd1, 8'd1, 8'd1};
        kernel_vectors[1] = {8'd1, 8'd1, 8'd1};
        kernel_vectors[2] = {8'd1, 8'd1, 8'd1};

        load_kernel();

        // Second kernel
        // [2 2 2]
        // [2 2 2]
        // [2 2 2]
        kernel_vectors[0] = {8'd2, 8'd2, 8'd2};
        kernel_vectors[1] = {8'd2, 8'd2, 8'd2};
        kernel_vectors[2] = {8'd2, 8'd2, 8'd2};

        load_kernel();

        for (idx = 0; idx < INPUT_DEPTH; idx = idx + 1) begin
            input_vectors[idx] = {8'd1, 8'd1, 8'd1};
            expected_outputs[idx] = 32'd18;
        end

        run_convolution();
        verify_outputs("Kernel after Kernel Load");

        $display("\n=========================================================");
        $display("TEST SUMMARY");
        $display("=========================================================");
        $display("Total Tests Run: %0d", current_test);
        $display("Total Assertions Passed: %0d", pass_count);
        $display("Total Assertions Failed: %0d", fail_count);
        $display("=========================================================");

        if (fail_count == 0) begin
            $display("*** ALL TESTS PASSED! ***");
        end else begin
            $display("*** SOME TESTS FAILED! ***");
        end
        $display("=========================================================");

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

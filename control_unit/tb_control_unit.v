`timescale 1ns / 1ps

module tb_control_unit;

    // Parameters
    parameter SA_DIM = 8;
    parameter SA_INPUT_FILL_TIME = 8;
    parameter CLK_PERIOD = 10;

    // DUT signals
    reg clk;
    reg rst_n;
    reg start;
    reg [6:0] cfg_N;
    reg [4:0] cfg_K;
    wire done;
    
    // Configuration outputs
    wire [6:0] dl_cfg_N;
    wire [4:0] dl_cfg_K;
    
    // Data loader interface
    wire start_loading_data_to_sram;
    reg done_loading_data_to_sram;
    
    wire start_pass_dl;
    
    // Kernel loading to SA
    wire load_kernel;
    wire [1:0] kernel_index;
    reg done_loading_kernel_to_sa;
    reg dl_output_data_valid;
    
    // Column loading to SA
    wire load_column;
    wire [5:0] load_column_index;
    reg done_loading_column_to_sa;
    
    // Output to DRAM
    wire start_sending_output_to_dram;
    reg done_sending_output_to_dram;
    
    wire systolic_data_valid;

    // Instantiate the DUT
    control_unit #(
        .SA_DIM(SA_DIM),
        .SA_INPUT_FILL_TIME(SA_INPUT_FILL_TIME)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .cfg_N(cfg_N),
        .cfg_K(cfg_K),
        .done(done),
        .dl_cfg_N(dl_cfg_N),
        .dl_cfg_K(dl_cfg_K),
        .start_loading_data_to_sram(start_loading_data_to_sram),
        .done_loading_data_to_sram(done_loading_data_to_sram),
        .start_pass_dl(start_pass_dl),
        .load_kernel(load_kernel),
        .kernel_index(kernel_index),
        .done_loading_kernel_to_sa(done_loading_kernel_to_sa),
        .dl_output_data_valid(dl_output_data_valid),
        .load_column(load_column),
        .load_column_index(load_column_index),
        .done_loading_column_to_sa(done_loading_column_to_sa),
        .start_sending_output_to_dram(start_sending_output_to_dram),
        .done_sending_output_to_dram(done_sending_output_to_dram),
        .systolic_data_valid(systolic_data_valid)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Task to reset the system
    task reset_system;
        begin
            rst_n = 0;
            start = 0;
            cfg_N = 0;
            cfg_K = 0;
            done_loading_data_to_sram = 0;
            done_loading_kernel_to_sa = 0;
            dl_output_data_valid = 0;
            done_loading_column_to_sa = 0;
            done_sending_output_to_dram = 0;
            #(CLK_PERIOD * 2);
            rst_n = 1;
            #(CLK_PERIOD * 2);
        end
    endtask

    // Task to simulate data loading to SRAM (kernel + image)
    task simulate_data_load;
        input integer cycles;
        begin
            @(posedge clk);
            wait(start_loading_data_to_sram);
            @(posedge clk);
            repeat(cycles) @(posedge clk);
            done_loading_data_to_sram = 1;
            @(posedge clk);
            done_loading_data_to_sram = 0;
            $display("[%0t] Data loading to SRAM completed", $time);
        end
    endtask

    // Task to simulate kernel loading to systolic array
    task simulate_kernel_to_sa;
        input integer cycles;
        begin
            @(posedge clk);
            wait(load_kernel);
            $display("[%0t] Loading kernel to SA (index=%0d)", $time, kernel_index);
            @(posedge clk);
            repeat(cycles) @(posedge clk);
            done_loading_kernel_to_sa = 1;
            @(posedge clk);
            done_loading_kernel_to_sa = 0;
            $display("[%0t] Kernel loading to SA completed (index=%0d)", $time, kernel_index);
        end
    endtask

    // Task to simulate column data streaming
    task simulate_column_streaming;
        input integer num_columns;
        input integer rows_per_column;
        integer col, row;
        begin
            for (col = 0; col < num_columns; col = col + 1) begin
                @(posedge clk);
                wait(load_column);
                $display("[%0t] Streaming column %0d (index=%0d)", $time, col, load_column_index);
                
                for (row = 0; row < rows_per_column; row = row + 1) begin
                    @(posedge clk);
                    dl_output_data_valid = 1;
                    @(posedge clk);
                    dl_output_data_valid = 0;
                end
                
                @(posedge clk);
            end
        end
    endtask

    // Task to simulate output storage to DRAM
    task simulate_output_store;
        input integer cycles;
        begin
            @(posedge clk);
            wait(start_sending_output_to_dram);
            @(posedge clk);
            repeat(cycles) @(posedge clk);
            done_sending_output_to_dram = 1;
            @(posedge clk);
            done_sending_output_to_dram = 0;
            $display("[%0t] Output storage to DRAM completed", $time);
        end
    endtask

    // Monitor state changes
    always @(dut.state) begin
        case(dut.state)
            4'd0: $display("[%0t] STATE: IDLE", $time);
            4'd1: $display("[%0t] STATE: CONFIG", $time);
            4'd2: $display("[%0t] STATE: LOAD_DATA_TO_SRAM", $time);
            4'd3: $display("[%0t] STATE: LOAD_K_TO_SA", $time);
            4'd4: $display("[%0t] STATE: COMPUTE", $time);
            4'd5: $display("[%0t] STATE: STORE_OUT", $time);
            4'd6: $display("[%0t] STATE: DONE_STATE", $time);
        endcase
    end

    // Test scenarios
    initial begin
        $display("=== Starting Control Unit Testbench ===");
        
        // Initialize signals
        reset_system();

        // Test Case 1: Small kernel (K = 3, N = 16) - K < SA_DIM
        $display("\n=== Test Case 1: K=3, N=16 (K < SA_DIM) ===");
        fork
            begin
                cfg_N = 16;
                cfg_K = 3;
                @(posedge clk);
                start = 1;
                @(posedge clk);
                start = 0;
            end
            
            simulate_data_load(10);
            simulate_kernel_to_sa(SA_DIM);
            simulate_column_streaming(14, 16);  // (N-K+1) columns, N rows each
            simulate_output_store(20);
        join
        
        wait(done);
        $display("[%0t] Test Case 1 completed - DONE signal asserted", $time);
        #(CLK_PERIOD * 5);

        // Reset for next test
        reset_system();

        // Test Case 2: Medium kernel (K = 5, N = 20)
        $display("\n=== Test Case 2: K=5, N=20 (K < SA_DIM) ===");
        fork
            begin
                cfg_N = 20;
                cfg_K = 5;
                @(posedge clk);
                start = 1;
                @(posedge clk);
                start = 0;
            end
            
            simulate_data_load(10);
            simulate_kernel_to_sa(SA_DIM);
            simulate_column_streaming(16, 20);  // (N-K+1) columns, N rows each
            simulate_output_store(20);
        join
        
        wait(done);
        $display("[%0t] Test Case 2 completed - DONE signal asserted", $time);
        #(CLK_PERIOD * 5);

        // Reset for next test
        reset_system();

        // Test Case 3: Edge case (K = SA_DIM = 8, N = 16)
        $display("\n=== Test Case 3: K=8, N=16 (K == SA_DIM) ===");
        fork
            begin
                cfg_N = 16;
                cfg_K = 8;
                @(posedge clk);
                start = 1;
                @(posedge clk);
                start = 0;
            end
            
            simulate_data_load(10);
            simulate_kernel_to_sa(SA_DIM);
            simulate_column_streaming(9, 16);  // (N-K+1) columns, N rows each
            simulate_output_store(20);
        join
        
        wait(done);
        $display("[%0t] Test Case 3 completed - DONE signal asserted", $time);
        #(CLK_PERIOD * 5);

        // Reset for next test
        reset_system();

        // Test Case 4: Large kernel (K = 12, N = 24) - K > SA_DIM (requires tiling)
        $display("\n=== Test Case 4: K=12, N=24 (K > SA_DIM, requires tiling) ===");
        fork
            begin
                cfg_N = 24;
                cfg_K = 12;
                @(posedge clk);
                start = 1;
                @(posedge clk);
                start = 0;
            end
            
            simulate_data_load(10);
            
            // Multiple kernel parts (4 parts for 12x12 with SA_DIM=8)
            simulate_kernel_to_sa(SA_DIM);  // Part 0
            simulate_column_streaming(13, 24);  // First tile
            
            simulate_kernel_to_sa(SA_DIM);  // Part 1
            simulate_column_streaming(13, 24);  // Second tile
            
            simulate_kernel_to_sa(SA_DIM);  // Part 2
            simulate_column_streaming(13, 24);  // Third tile
            
            simulate_kernel_to_sa(SA_DIM);  // Part 3
            simulate_column_streaming(13, 24);  // Fourth tile
            
            simulate_output_store(50);
        join
        
        wait(done);
        $display("[%0t] Test Case 4 completed - DONE signal asserted", $time);
        #(CLK_PERIOD * 5);

        $display("\n=== All Test Cases Completed Successfully ===");
        #(CLK_PERIOD * 10);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 10000);
        $display("ERROR: Simulation timeout!");
        $finish;
    end

    // Optional: Waveform dumping
    initial begin
        $dumpfile("tb_control_unit.vcd");
        $dumpvars(0, tb_control_unit);
    end

endmodule

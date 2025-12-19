`timescale 1ns / 1ps

module tb_control_unit;

    // Parameters
    parameter SA_DIM = 8;
    parameter SA_INPUT_FILL_TIME = 8;
    parameter CLK_PERIOD = 10;

    // DUT signals
    reg clk;
    reg busy_clk;
    reg rst_n;
    reg start;
    reg [5:0] cfg_N;
    reg [3:0] cfg_K;
    wire done;
    
    // Data loader interface
    reg dl_busy;
    
    // Input data stream from DRAM
    wire rx_ready;
    reg rx_valid;
    
    // Output data stream to DRAM
    reg tx_ready;
    wire tx_valid;
    
    // Configuration outputs
    wire [5:0] dl_cfg_N;
    wire [3:0] dl_cfg_K;
    
    // Control signals to data loader
    wire start_loading_kernel_to_sram;
    wire start_loading_image_to_sram;
    wire load_kernel;
    wire [1:0] kernel_index;
    wire load_column;
    wire [5:0] load_column_index;
    wire systolic_data_valid;
    wire start_sending_output_to_dram;

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
        .dl_busy(busy_clk),
        .rx_ready(rx_ready),
        .rx_valid(rx_valid),
        .tx_ready(tx_ready),
        .tx_valid(tx_valid),
        .dl_cfg_N(dl_cfg_N),
        .dl_cfg_K(dl_cfg_K),
        .start_loading_kernel_to_sram(start_loading_kernel_to_sram),
        .start_loading_image_to_sram(start_loading_image_to_sram),
        .load_kernel(load_kernel),
        .kernel_index(kernel_index),
        .load_column(load_column),
        .load_column_index(load_column_index),
        .systolic_data_valid(systolic_data_valid),
        .start_sending_output_to_dram(start_sending_output_to_dram)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        busy_clk = 1;  // Start opposite to clk
        forever #(CLK_PERIOD * 2) busy_clk = ~busy_clk;
    end

    // Task to reset the system
    task reset_system;
        begin
            rst_n = 0;
            start = 0;
            cfg_N = 0;
            cfg_K = 0;
            dl_busy = 0;
            rx_valid = 0;
            tx_ready = 0;
            #(CLK_PERIOD * 2);
            rst_n = 1;
            #(CLK_PERIOD * 2);
        end
    endtask

    // Task to simulate data loader busy for kernel loading
    task simulate_kernel_load;
        input integer cycles;
        begin
            @(posedge clk);
            wait(start_loading_kernel_to_sram);
            @(posedge clk);
            dl_busy = 1;
            repeat(cycles) @(posedge clk);
            dl_busy = 0;
            $display("[%0t] Kernel loading to SRAM completed", $time);
        end
    endtask

    // Task to simulate data loader busy for image loading
    task simulate_image_load;
        input integer cycles;
        begin
            @(posedge clk);
            wait(start_loading_image_to_sram);
            @(posedge clk);
            dl_busy = 1;
            repeat(cycles) @(posedge clk);
            dl_busy = 0;
            $display("[%0t] Image loading to SRAM completed", $time);
        end
    endtask

    // Task to simulate kernel loading to systolic array
    task simulate_kernel_to_sa;
        input integer cycles;
        begin
            @(posedge clk);
            wait(load_kernel);
            @(posedge clk);
            dl_busy = 1;
            repeat(cycles) @(posedge clk);
            dl_busy = 0;
            $display("[%0t] Kernel loading to SA completed (index=%0d)", $time, kernel_index);
        end
    endtask

    // Task to simulate output storage to DRAM
    task simulate_output_store;
        input integer cycles;
        begin
            @(posedge clk);
            wait(start_sending_output_to_dram);
            @(posedge clk);
            tx_ready = 1;
            dl_busy = 1;
            repeat(cycles) @(posedge clk);
            dl_busy = 0;
            repeat(2) @(posedge clk);
            tx_ready = 0;
            $display("[%0t] Output storage to DRAM completed", $time);
        end
    endtask

    // Monitor state changes
    always @(dut.state) begin
        case(dut.state)
            4'd0: $display("[%0t] STATE: IDLE", $time);
            4'd1: $display("[%0t] STATE: CONFIG", $time);
            4'd2: $display("[%0t] STATE: WAIT_MEM", $time);
            4'd3: $display("[%0t] STATE: LOAD_K_TO_SRAM", $time);
            4'd4: $display("[%0t] STATE: WAIT_LOADING_KERNEL_TO_SRAM", $time);
            4'd5: $display("[%0t] STATE: LOAD_I_TO_SRAM", $time);
            4'd6: $display("[%0t] STATE: WAIT_LOADING_IMAGE_TO_SRAM", $time);
            4'd7: $display("[%0t] STATE: LOAD_K_TO_SA", $time);
            4'd8: $display("[%0t] STATE: WAIT_LOADING_K_TO_SA", $time);
            4'd9: $display("[%0t] STATE: COMPUTE", $time);
            4'd10: $display("[%0t] STATE: WAIT_MEM_OUT", $time);
            4'd11: $display("[%0t] STATE: STORE_OUT", $time);
            4'd12: $display("[%0t] STATE: DONE_STATE", $time);
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
                start = 1;
                @(posedge clk);
                start = 0;
                
                // Wait for rx_ready
                wait(rx_ready);
                @(posedge clk);
                rx_valid = 1;
                @(posedge clk);
                rx_valid = 0;
            end
            
            simulate_kernel_load(1);
            simulate_image_load(1);
            simulate_kernel_to_sa(SA_DIM);
            simulate_output_store(1);
        join
        
        $display("[%0t] Waiting for done state: done=%b, state=%0d", $time, done, dut.state);
        
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
                start = 1;
                @(posedge clk);
                @(posedge clk);
                @(posedge clk);
                start = 0;
                
                wait(rx_ready);
                @(posedge clk);
                rx_valid = 1;
                @(posedge clk);
                rx_valid = 0;
            end
            
            simulate_kernel_load(1);
            simulate_image_load(1);
            simulate_kernel_to_sa(SA_DIM);
            simulate_output_store(1);
        join
        
        wait(done);
        $display("[%0t] Test Case 2 completed - DONE signal asserted", $time);
        #(CLK_PERIOD * 5);

        // Reset for next test
        reset_system();

        // Test Case 3: Large kernel (K = 12, N = 24) - K > SA_DIM
        $display("\n=== Test Case 3: K=12, N=24 (K > SA_DIM, requires tiling) ===");
        fork
            begin
                cfg_N = 24;
                cfg_K = 12;
                start = 1;
                @(posedge clk);
                @(posedge clk);
                start = 0;
                
                wait(rx_ready);
                @(posedge clk);
                rx_valid = 1;
                @(posedge clk);
                rx_valid = 0;
            end
            
            // simulate_image_load(50);
            
            // // Multiple kernel parts need to be loaded (4 parts for 12x12 with SA_DIM=8)
            // simulate_kernel_to_sa(SA_DIM);  // Part 0
            // simulate_kernel_to_sa(SA_DIM);  // Part 1
            // simulate_kernel_to_sa(SA_DIM);  // Part 2
            // simulate_kernel_to_sa(SA_DIM);  // Part 3
            
            simulate_output_store(1);
        join
        
        wait(done);
        $display("[%0t] Test Case 3 completed - DONE signal asserted", $time);
        #(CLK_PERIOD * 5);

        // Reset for next test
        reset_system();

        // Test Case 4: Edge case (K = SA_DIM = 8, N = 16)
        $display("\n=== Test Case 4: K=8, N=16 (K == SA_DIM) ===");
        fork
            begin
                cfg_N = 16;
                cfg_K = 8;
                start = 1;
                @(posedge clk);
                @(posedge clk);
                start = 0;
                
                wait(rx_ready);
                @(posedge clk);
                rx_valid = 1;
                @(posedge clk);
                rx_valid = 0;
            end
            
            simulate_kernel_load(1);
            simulate_image_load(1);
            simulate_kernel_to_sa(SA_DIM);
            simulate_output_store(1);
        join
        
        wait(done);
        $display("[%0t] Test Case 4 completed - DONE signal asserted", $time);
        #(CLK_PERIOD * 5);

        // Reset for next test
        reset_system();

        // Test Case 5: Large kernel (K = 15, N = 61) - K > SA_DIM
        $display("\n=== Test Case 5: K=15, N=61 (K > SA_DIM, requires tiling) ===");
        fork
            begin
                cfg_N = 61;
                cfg_K = 15;
                start = 1;
                @(posedge clk);
                @(posedge clk);
                start = 0;
                
                wait(rx_ready);
                @(posedge clk);
                rx_valid = 1;
                @(posedge clk);
                rx_valid = 0;
            end
            
            simulate_kernel_load(1);
            simulate_image_load(1);
            
            // Multiple kernel parts need to be loaded (4 parts for 15x15 with SA_DIM=8)
            simulate_kernel_to_sa(SA_DIM);  // Part 0
            simulate_kernel_to_sa(SA_DIM);  // Part 1
            simulate_kernel_to_sa(SA_DIM);  // Part 2
            simulate_kernel_to_sa(SA_DIM);  // Part 3
            
            simulate_output_store(50);
        join
        
        wait(done);
        $display("[%0t] Test Case 5 completed - DONE signal asserted", $time);
        #(CLK_PERIOD * 5);

        $display("\n=== All Test Cases Completed Successfully ===");
        #(CLK_PERIOD * 10);
        // $finish;
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

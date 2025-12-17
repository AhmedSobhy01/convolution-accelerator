# Project Structure

```
rtl/         - All source Verilog files (Accelerator, PE, Memory Wrapper)
scripts/     - Python/Shell scripts for testing, testbench generation, analysis
config/      - OpenLane synthesis config.json files
final/       - Final OpenLane outputs (GDSII, LEF, reports only)
docs/        - For guidelines, ambigous parts of the code or any of your great artistic diagrams
sim/         - For do files
tb/          - All testbench Verilog files
```

## Naming Conventions

### Files

- Use lowercase with underscores: `memory_wrapper.v`, `processing_element.v`
- One module per file, filename matches module name

### Modules and Instances

- Modules: lowercase with underscores: `accelerator_top`, `pe_array`
- Instances: descriptive with index if applicable: `pe_0`, `mem_ctrl`
>[!NOTE]
>A nice example would be the SRAM interface given to us in the project document. You can find it at page 6.

### Parameters and Constants

- Uppercase with underscores: `DATA_WIDTH`, `ADDR_BITS`

### Formatting
- **Module header**: Parameters on same line as module declaration, ports on separate lines

```verilog
module name #(parameter WIDTH = 32, parameter SIZE = 4)
(
    input wire clk,
    input wire rst,
    ...
);
```

- **Port lists**: Opening parenthesis on same line as module/instance, one port per line, aligned
- **Instance parameters**: On same line with instantiation
```verilog
pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
.clk(clk),
.rst(rst),
...
);
```

- **Signal declarations**: Group by type, align across columns
- **Always blocks**: `begin` on same line as sensitivity list with the `end` on the same column as the `always`

```verilog
always @(*) begin
    // statements
end
```

- **Generate blocks**: Named blocks with descriptive labels

## Testbenches
- File naming: `module_name_tb.v`
- Module naming: `module_name_tb`
- Use `$display` with similar formats as if we were able to use assertions (system verilog privilege)
also print the total number of failed/passed cases at the end of your tb.
```verilog
$display("[PASS] %s: Expected=%0d, Got=%0d at time %0t", msg, expected, actual, $time);
$display("[FAIL] %s: Expected=%0d, Got=%0d at time %0t", msg, expected, actual, $time);
  
$display("Test Summary:");
$display("Passed:      %0d", pass_count);
$display("Failed:      %0d", fail_count);
```

#!/bin/bash
# ============================================================================
# verify_gls.sh - Gate-Level Simulation Script for Convolution Accelerator
# ============================================================================
# Usage: ./scripts/verify_gls.sh <run_tag>
# Example: ./scripts/verify_gls.sh baseline

set -e

# --- Configuration ---
RUN_TAG="${1:-baseline}"
USERNAME="${USER:-$(whoami)}"
PDK_VERSION="0fe599b2afb6708d281543108caf8310912f54af"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Paths ---
TESTBENCH="${PROJECT_ROOT}/tb/tb_conv_accel_simple.v"
FINAL_NETLIST="${PROJECT_ROOT}/runs/${RUN_TAG}/final/nl/conv_accelerator_top.nl.v"
SYNTH_NETLIST="${PROJECT_ROOT}/runs/${RUN_TAG}/06-yosys-synthesis/conv_accelerator_top.nl.v"

# PDK Paths (adjust for your environment)
PDK_ROOT="/home/${USERNAME}/.volare/volare/sky130/versions/${PDK_VERSION}"
STD_CELL_VERILOG="${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v"
PRIMITIVES_VERILOG="${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v"

# SRAM Blackbox Models (for GLS)
SRAM_MODELS="${PROJECT_ROOT}/data-loader-agu/src/simple_ram_models.v"

# --- Output ---
BIN_DIR="${PROJECT_ROOT}/outputs/bin"
WAVES_DIR="${PROJECT_ROOT}/outputs/waves"
GLS_EXECUTABLE="${BIN_DIR}/gls_conv_accel_${RUN_TAG}.vvp"

mkdir -p "$BIN_DIR" "$WAVES_DIR"

# --- Select Netlist ---
if [ -f "$FINAL_NETLIST" ]; then
    NETLIST="$FINAL_NETLIST"
    echo "Using FINAL netlist: $NETLIST"
elif [ -f "$SYNTH_NETLIST" ]; then
    NETLIST="$SYNTH_NETLIST"
    echo "Using SYNTHESIS netlist: $NETLIST"
else
    echo "ERROR: No netlist found in runs/${RUN_TAG}/"
    echo "  Expected: $FINAL_NETLIST"
    echo "  Or: $SYNTH_NETLIST"
    exit 1
fi

# --- Check Files Exist ---
echo "Checking required files..."

if [ ! -f "$TESTBENCH" ]; then
    echo "ERROR: Testbench not found: $TESTBENCH"
    exit 1
fi

if [ ! -f "$STD_CELL_VERILOG" ]; then
    echo "WARNING: Standard cell Verilog not found: $STD_CELL_VERILOG"
    echo "Make sure PDK_ROOT and PDK_VERSION are correct for your environment."
    echo ""
    echo "Alternative: Set environment variables:"
    echo "  export PDK_ROOT=/path/to/pdk"
    echo ""
fi

if [ ! -f "$PRIMITIVES_VERILOG" ]; then
    echo "WARNING: Primitives Verilog not found: $PRIMITIVES_VERILOG"
fi

# --- Compile GLS ---
echo ""
echo "========================================"
echo "Compiling Gate-Level Simulation"
echo "Run Tag: ${RUN_TAG}"
echo "========================================"

iverilog -g2012 \
    -o "$GLS_EXECUTABLE" \
    -Wnone \
    -DFUNCTIONAL \
    -DUNIT_DELAY="#1" \
    "$TESTBENCH" \
    "$NETLIST" \
    "$SRAM_MODELS" \
    "$STD_CELL_VERILOG" \
    "$PRIMITIVES_VERILOG"

if [ $? -ne 0 ]; then
    echo "ERROR: GLS compilation failed!"
    exit 1
fi

echo "GLS Compilation successful: $GLS_EXECUTABLE"

# --- Run GLS ---
echo ""
echo "Running Gate-Level Simulation..."
echo "========================================"

cd "$PROJECT_ROOT"
vvp "$GLS_EXECUTABLE"

if [ $? -ne 0 ]; then
    echo "ERROR: GLS failed!"
    exit 1
fi

# --- Move Waveforms ---
if ls *.vcd 1> /dev/null 2>&1; then
    mv *.vcd "$WAVES_DIR/"
    echo "Waveforms saved to: $WAVES_DIR/"
fi

echo ""
echo "========================================"
echo "Gate-Level Simulation Complete"
echo "========================================"
echo ""
echo "Next: Compare outputs with expected results"
echo "  python scripts/compare_output.py"

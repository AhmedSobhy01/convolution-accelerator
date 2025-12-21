#!/bin/bash
# ============================================================================
# verify.sh - RTL Simulation Script for Convolution Accelerator
# ============================================================================
# Usage: ./scripts/verify.sh [test_case]
# Example: ./scripts/verify.sh 01

set -e

# --- Configuration ---
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_CASE="${1:-01}"

# --- Source Files (all in rtl/) ---
RTL_FILES=(
    "${PROJECT_ROOT}/rtl/conv_accelerator_top.v"
    "${PROJECT_ROOT}/rtl/control_unit.v"
    "${PROJECT_ROOT}/rtl/pe.v"
    "${PROJECT_ROOT}/rtl/systolic_array.v"
    "${PROJECT_ROOT}/rtl/dl_dma_rx.v"
    "${PROJECT_ROOT}/rtl/byte_window_streamer.v"
    "${PROJECT_ROOT}/rtl/kernel_window_streamer.v"
    "${PROJECT_ROOT}/rtl/dl_sa_writeback.v"
    "${PROJECT_ROOT}/rtl/dl_drain_stream.v"
    "${PROJECT_ROOT}/rtl/sram0_wrapper.v"
    "${PROJECT_ROOT}/rtl/sram1_wrapper.v"
    "${PROJECT_ROOT}/rtl/simple_ram_models.v"
)

TESTBENCH="${PROJECT_ROOT}/rtl/tb_conv_accel_simple.v"

# --- Output Paths ---
BIN_DIR="${PROJECT_ROOT}/outputs/bin"
WAVES_DIR="${PROJECT_ROOT}/outputs/waves"
OUTPUT_FILE="${PROJECT_ROOT}/output_data.txt"

mkdir -p "$BIN_DIR" "$WAVES_DIR"

# --- Check Files Exist ---
for file in "${RTL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: Source file not found: $file"
        exit 1
    fi
done

if [ ! -f "$TESTBENCH" ]; then
    echo "ERROR: Testbench not found: $TESTBENCH"
    exit 1
fi

# --- Compile ---
echo "========================================"
echo "Compiling Convolution Accelerator RTL"
echo "Test Case: ${TEST_CASE}"
echo "========================================"

EXECUTABLE="${BIN_DIR}/conv_accel_test${TEST_CASE}.vvp"

iverilog -g2012 \
    -DTEST_CASE=${TEST_CASE} \
    -o "$EXECUTABLE" \
    "${RTL_FILES[@]}" \
    "$TESTBENCH"

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed!"
    exit 1
fi

echo "Compilation successful: $EXECUTABLE"

# --- Run Simulation ---
echo ""
echo "Running RTL Simulation..."
echo "========================================"

cd "$PROJECT_ROOT"
vvp "$EXECUTABLE"

if [ $? -ne 0 ]; then
    echo "ERROR: Simulation failed!"
    exit 1
fi

# --- Move Waveforms ---
if ls *.vcd 1> /dev/null 2>&1; then
    mv *.vcd "$WAVES_DIR/"
    echo "Waveforms saved to: $WAVES_DIR/"
fi

# --- Compare Output ---
if [ -f "$OUTPUT_FILE" ]; then
    echo ""
    echo "Output generated: $OUTPUT_FILE"
    echo "Run 'python scripts/compare_output.py' to verify against expected"
fi

echo ""
echo "========================================"
echo "RTL Simulation Complete"
echo "========================================"

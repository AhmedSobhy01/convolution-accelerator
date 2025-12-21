#!/bin/bash
# ============================================================================
# check.sh - Quick Reference Commands for Convolution Accelerator
# ============================================================================
# This file contains common commands for development and verification.
# Copy/paste individual commands as needed.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================"
echo "Convolution Accelerator - Quick Commands"
echo "========================================"
echo ""

# ============================================================================
# RTL SIMULATION
# ============================================================================
echo "--- RTL Simulation ---"
echo ""

# Single test case with ModelSim
echo "# ModelSim simulation (GUI):"
echo "vsim -do scripts/run_simple.do"
echo ""

# Single test case with Icarus
echo "# Icarus Verilog simulation:"
echo "./scripts/verify.sh 01"
echo ""

# Run all test cases with Python
echo "# Run all test cases:"
echo "python scripts/run_all_tests.py"
echo ""

# ============================================================================
# OPENLANE SYNTHESIS
# ============================================================================
echo "--- OpenLane Synthesis ---"
echo ""

echo "# Baseline synthesis:"
echo "openlane config/config.json --run-tag baseline"
echo ""

echo "# Optimized synthesis (after tuning):"
echo "openlane config/config.json --run-tag optimized"
echo ""

echo "# Check metrics after run:"
echo "cat runs/<run-tag>/final/metrics.csv"
echo ""

# ============================================================================
# GATE-LEVEL SIMULATION
# ============================================================================
echo "--- Gate-Level Simulation ---"
echo ""

echo "# Run GLS after synthesis:"
echo "./scripts/verify_gls.sh baseline"
echo ""

# ============================================================================
# OUTPUT VERIFICATION
# ============================================================================
echo "--- Output Verification ---"
echo ""

echo "# Compare output with expected:"
echo "python scripts/compare_output.py"
echo ""

echo "# View waveforms (GTKWave):"
echo "gtkwave outputs/waves/tb_conv_accel_simple.vcd"
echo ""

# ============================================================================
# DELIVERABLES
# ============================================================================
echo "--- Collecting Deliverables ---"
echo ""

echo "# Copy final outputs for submission:"
echo "mkdir -p final"
echo "cp -r runs/<best-run>/final/* final/"
echo ""

echo "# Key files to submit:"
echo "# - rtl/           (Verilog sources)"
echo "# - scripts/       (Test scripts)"
echo "# - config/        (OpenLane config)"
echo "# - final/         (Synthesis outputs)"
echo "# - report.pdf     (Documentation)"
echo ""

echo "========================================"
echo "For detailed instructions, see:"
echo "  config/OPENLANE_GUIDE.md"
echo "========================================"

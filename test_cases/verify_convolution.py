#!/usr/bin/env python3
"""
Convolution Test Verification Script
Parses test case files, performs convolution, and compares with gold standard.
"""

import numpy as np
import sys
from pathlib import Path


def parse_config(config_file):
    """Parse configuration file to extract N, K, and Output_Size."""
    config = {}
    with open(config_file, 'r') as f:
        for line in f:
            line = line.strip()
            if '=' in line:
                key, value = line.split('=')
                config[key.strip()] = int(value.strip())
    return config


def read_hex_file(hex_file):
    """Read hex file and return as numpy array of uint8 values."""
    values = []
    with open(hex_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                values.append(int(line, 16))
    return np.array(values, dtype=np.uint8)


def perform_convolution(input_data, kernel, N, K):
    """
    Perform 2D convolution.
    
    Args:
        input_data: Flattened input array
        kernel: Flattened kernel array
        N: Input dimension (N x N)
        K: Kernel dimension (K x K)
    
    Returns:
        Flattened output array
    """
    # Reshape input and kernel
    input_2d = input_data.reshape(N, N)
    kernel_2d = kernel.reshape(K, K)
    
    # Calculate output size
    output_size = N - K + 1
    output = np.zeros((output_size, output_size), dtype=np.uint16)
    
    # Perform convolution
    for i in range(output_size):
        for j in range(output_size):
            # Extract window
            window = input_2d[i:i+K, j:j+K]
            # Compute dot product
            result = np.sum(window * kernel_2d)
            # Clip to 8-bit unsigned range
            output[i, j] = min(result, 255)
    
    # Return flattened output as uint8
    return output.flatten().astype(np.uint8)


def compare_results(computed, gold):
    """Compare computed results with gold standard."""
    if len(computed) != len(gold):
        print(f"ERROR: Length mismatch! Computed: {len(computed)}, Gold: {len(gold)}")
        return False
    
    mismatches = []
    for i, (c, g) in enumerate(zip(computed, gold)):
        if c != g:
            mismatches.append((i, c, g))
    
    if mismatches:
        print(f"\n❌ FAIL: {len(mismatches)} mismatches found out of {len(gold)} values")
        print("\nFirst 10 mismatches:")
        for idx, comp, gld in mismatches[:10]:
            print(f"  Index {idx:3d}: Computed=0x{comp:02X} ({comp:3d}), Gold=0x{gld:02X} ({gld:3d}), Diff={int(comp)-int(gld):+4d}")
        
        if len(mismatches) > 10:
            print(f"  ... and {len(mismatches)-10} more mismatches")
        return False
    else:
        print(f"\n✓ PASS: All {len(gold)} values match!")
        return True


def print_matrix(name, data, rows, cols, hex_format=True):
    """Print matrix in readable format."""
    print(f"\n{name}:")
    for i in range(rows):
        row_data = data[i*cols:(i+1)*cols]
        if hex_format:
            print("  " + " ".join(f"{val:02X}" for val in row_data))
        else:
            print("  " + " ".join(f"{val:3d}" for val in row_data))


def main(test_case_prefix):
    """Main verification function."""
    print("=" * 70)
    print("Convolution Test Verification")
    print("=" * 70)
    
    # Build file paths
    base_path = Path(__file__).parent
    config_file = base_path / f"{test_case_prefix}_config.txt"
    input_file = base_path / f"{test_case_prefix}_in.hex"
    weight_file = base_path / f"{test_case_prefix}_weight.hex"
    gold_file = base_path / f"{test_case_prefix}_gold.hex"
    
    # Check if files exist
    for f in [config_file, input_file, weight_file, gold_file]:
        if not f.exists():
            print(f"ERROR: File not found: {f}")
            return False
    
    # Parse configuration
    print(f"\nReading configuration from: {config_file.name}")
    config = parse_config(config_file)
    N = config['N']
    K = config['K']
    expected_output_size = config['Output_Size']
    
    print(f"  N (Input size): {N}x{N} = {N*N}")
    print(f"  K (Kernel size): {K}x{K} = {K*K}")
    print(f"  Expected output size: {expected_output_size}")
    print(f"  Calculated output: {N-K+1}x{N-K+1} = {(N-K+1)*(N-K+1)}")
    
    # Read input data
    print(f"\nReading input from: {input_file.name}")
    input_data = read_hex_file(input_file)
    print(f"  Read {len(input_data)} bytes")
    
    if len(input_data) != N * N:
        print(f"  WARNING: Expected {N*N} bytes, got {len(input_data)}")
    
    # Read kernel weights
    print(f"\nReading kernel from: {weight_file.name}")
    kernel_data = read_hex_file(weight_file)
    print(f"  Read {len(kernel_data)} bytes")
    
    if len(kernel_data) != K * K:
        print(f"  WARNING: Expected {K*K} bytes, got {len(kernel_data)}")
    
    # Read gold standard
    print(f"\nReading gold standard from: {gold_file.name}")
    gold_data = read_hex_file(gold_file)
    print(f"  Read {len(gold_data)} bytes")
    
    # Display input and kernel
    print_matrix("Input Data (Hex)", input_data, N, N, hex_format=True)
    print_matrix("Kernel Weights (Hex)", kernel_data, K, K, hex_format=True)
    
    # Perform convolution
    print("\n" + "-" * 70)
    print("Performing convolution...")
    print("-" * 70)
    computed_output = perform_convolution(input_data, kernel_data, N, K)
    
    output_dim = N - K + 1
    print_matrix("Computed Output (Hex)", computed_output, output_dim, output_dim, hex_format=True)
    print_matrix("Gold Output (Hex)", gold_data, output_dim, output_dim, hex_format=True)
    
    # Compare results
    print("\n" + "-" * 70)
    print("Comparing Results")
    print("-" * 70)
    result = compare_results(computed_output, gold_data)
    
    print("\n" + "=" * 70)
    if result:
        print("VERIFICATION: ✓ PASSED")
    else:
        print("VERIFICATION: ❌ FAILED")
    print("=" * 70)
    
    return result


if __name__ == "__main__":
    if len(sys.argv) > 1:
        test_prefix = sys.argv[1]
    else:
        # Default to the first test case
        test_prefix = "01_Basic_Minimal"
    
    success = main(test_prefix)
    sys.exit(0 if success else 1)

import sys

def read_hex_file(filename):
    values = []
    with open(filename, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if line:
                try:
                    values.append((line_num, int(line, 16)))
                except ValueError:
                    print(f"Warning: Invalid hex value '{line}' at line {line_num}")
    return values

def compare_outputs(output_file, expected_file):
    output = read_hex_file(output_file)
    expected = read_hex_file(expected_file)

    print(f"Output file:   {output_file} ({len(output)} values)")
    print(f"Expected file: {expected_file} ({len(expected)} values)")
    print("-" * 50)

    if len(output) != len(expected):
        print(f"ERROR: Size mismatch! Output has {len(output)} values, expected {len(expected)}")

    errors = []
    matches = 0

    for i in range(min(len(output), len(expected))):
        out_line, out_val = output[i]
        exp_line, exp_val = expected[i]

        if out_val == exp_val:
            matches += 1
        else:
            errors.append((i, out_val, exp_val))

    if errors:
        print(f"\nMismatches found: {len(errors)}")
        print("\nFirst 20 mismatches:")
        print(f"{'Index':<8} {'Output':<10} {'Expected':<10} {'Diff':<10}")
        print("-" * 40)
        for idx, out_val, exp_val in errors[:20]:
            diff = out_val - exp_val
            print(f"{idx:<8} 0x{out_val:02X} ({out_val:3d})  0x{exp_val:02X} ({exp_val:3d})  {diff:+d}")

        if len(errors) > 20:
            print(f"... and {len(errors) - 20} more mismatches")
    else:
        print("\nAll values match!")

    print("-" * 50)
    print(f"Summary: {matches}/{min(len(output), len(expected))} values match")

    return len(errors) == 0 and len(output) == len(expected)

if __name__ == "__main__":
    output_file = sys.argv[1] if len(sys.argv) > 1 else "output_data.txt"
    expected_file = sys.argv[2] if len(sys.argv) > 2 else "output_expected.txt"

    try:
        success = compare_outputs(output_file, expected_file)
        sys.exit(0 if success else 1)
    except FileNotFoundError as e:
        print(f"Error: {e}")
        sys.exit(1)

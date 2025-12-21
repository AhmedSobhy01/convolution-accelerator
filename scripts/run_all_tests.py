import os
import sys
import subprocess
import argparse
import time
from pathlib import Path
from typing import List, Tuple, Optional
from dataclasses import dataclass
from enum import Enum


class TestStatus(Enum):
    PASSED = "PASSED"
    FAILED = "FAILED"
    ERROR = "ERROR"
    SKIPPED = "SKIPPED"


@dataclass
class TestResult:
    test_num: int
    test_name: str
    status: TestStatus
    output_count: int
    expected_count: int
    matches: int
    mismatches: int
    error_message: str = ""
    duration: float = 0.0


TEST_CASES = {
    1: "01_Basic_Minimal",
    2: "02_Basic_Identity",
    3: "03_Basic_AllOnes",
    4: "04_Regular_Standard",
    5: "05_Regular_LargeHalo",
    6: "06_Regular_PingPong",
    7: "07_Adv_MaxSpec",
    8: "08_Adv_Throughput",
    9: "09_Pro_PartialTile",
    10: "10_Pro_Saturation",
}


def get_project_root() -> Path:
    script_path = Path(__file__).resolve()
    return script_path.parent.parent


def read_hex_file(filepath: Path) -> List[int]:
    values = []
    if not filepath.exists():
        raise FileNotFoundError(f"File not found: {filepath}")

    with open(filepath, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if line:
                try:
                    values.append(int(line, 16))
                except ValueError:
                    print(f"  Warning: Invalid hex value '{line}' at line {line_num}")
    return values


def compare_outputs(output_file: Path, expected_file: Path) -> Tuple[int, int, int, List[Tuple[int, int, int]]]:
    output = read_hex_file(output_file)
    expected = read_hex_file(expected_file)

    mismatches = []
    matches = 0

    for i in range(min(len(output), len(expected))):
        if output[i] == expected[i]:
            matches += 1
        else:
            mismatches.append((i, output[i], expected[i]))

    return len(output), len(expected), matches, mismatches


def generate_do_script(project_root: Path, test_num: int, output_do_file: Path) -> None:
    do_content = f"""# Auto-generated DO script for test case {test_num}
# ==============================================================================

# 1. COMPILATION
vlib work
vmap work work

vlog -work work control_unit/control_unit.v
vlog -work work data-loader-agu/src/dl_dma_rx.v
vlog -work work data-loader-agu/src/byte_window_streamer.v
vlog -work work data-loader-agu/src/kernel_window_streamer.v
vlog -work work data-loader-agu/src/dl_sa_writeback.v
vlog -work work data-loader-agu/src/dl_drain_stream.v
vlog -work work data-loader-agu/src/simple_ram_models.v
vlog -work work data-loader-agu/src/sram0_wrapper.v
vlog -work work data-loader-agu/src/sram1_wrapper.v
vlog -work work rtl/pe.v
vlog -work work rtl/systolic_array.v
vlog -work work conv_accelerator_top.v
vlog -work work +define+TEST_CASE={test_num} tb/tb_conv_accel_simple.v

# 2. START SIMULATION
vsim -c -voptargs=+acc work.tb_conv_accel_simple -GTEST_CASE={test_num}

# 3. RUN
run -all

# 4. EXIT
quit -f
"""
    with open(output_do_file, 'w') as f:
        f.write(do_content)


def run_modelsim(project_root: Path, do_file: Path, verbose: bool = False) -> Tuple[bool, str]:
    # Try different ModelSim commands
    modelsim_commands = ['vsim', 'questasim', 'modelsim']

    cmd = None
    for msim_cmd in modelsim_commands:
        try:
            # Check if command exists
            result = subprocess.run(
                [msim_cmd, '-version'] if sys.platform != 'win32' else ['where', msim_cmd],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0 or 'vsim' in result.stdout.lower():
                cmd = msim_cmd
                break
        except (subprocess.TimeoutExpired, FileNotFoundError):
            continue

    if cmd is None:
        cmd = 'vsim'

    try:
        process = subprocess.run(
            [cmd, '-c', '-do', str(do_file)],
            cwd=project_root,
            capture_output=True,
            text=True,
            timeout=300
        )

        output = process.stdout + process.stderr

        if verbose:
            print(output)

        if 'Error' in output and 'Error loading design' not in output:
            if 'Fatal' in output or 'FATAL' in output:
                return False, output

        return True, output

    except subprocess.TimeoutExpired:
        return False, "Simulation timeout (5 minutes exceeded)"
    except FileNotFoundError:
        return False, f"ModelSim not found. Please ensure '{cmd}' is in your PATH."
    except Exception as e:
        return False, str(e)


def run_test_case(project_root: Path, test_num: int, verbose: bool = False) -> TestResult:
    test_name = TEST_CASES.get(test_num)
    if not test_name:
        return TestResult(
            test_num=test_num,
            test_name="Unknown",
            status=TestStatus.SKIPPED,
            output_count=0,
            expected_count=0,
            matches=0,
            mismatches=0,
            error_message=f"Invalid test number: {test_num}"
        )

    print(f"\n{'='*60}")
    print(f"Running Test Case {test_num}: {test_name}")
    print('='*60)

    start_time = time.time()

    test_cases_dir = project_root / "test_cases"
    config_file = test_cases_dir / f"{test_name}_config.txt"
    input_file = test_cases_dir / f"{test_name}_in.hex"
    kernel_file = test_cases_dir / f"{test_name}_weight.hex"
    gold_file = test_cases_dir / f"{test_name}_gold.hex"

    for f in [config_file, input_file, kernel_file, gold_file]:
        if not f.exists():
            return TestResult(
                test_num=test_num,
                test_name=test_name,
                status=TestStatus.ERROR,
                output_count=0,
                expected_count=0,
                matches=0,
                mismatches=0,
                error_message=f"Missing file: {f.name}",
                duration=time.time() - start_time
            )

    do_file = project_root / "scripts" / f"run_test_{test_num}.do"
    generate_do_script(project_root, test_num, do_file)

    print(f"  Running simulation...")
    success, output = run_modelsim(project_root, do_file, verbose)

    if not success:
        return TestResult(
            test_num=test_num,
            test_name=test_name,
            status=TestStatus.ERROR,
            output_count=0,
            expected_count=0,
            matches=0,
            mismatches=0,
            error_message=f"Simulation failed: {output[:500]}",
            duration=time.time() - start_time
        )

    output_file = project_root / "output_data.txt"
    if not output_file.exists():
        return TestResult(
            test_num=test_num,
            test_name=test_name,
            status=TestStatus.ERROR,
            output_count=0,
            expected_count=0,
            matches=0,
            mismatches=0,
            error_message="No output file generated",
            duration=time.time() - start_time
        )

    print(f"  Comparing outputs...")
    try:
        output_count, expected_count, matches, mismatches = compare_outputs(output_file, gold_file)
    except Exception as e:
        return TestResult(
            test_num=test_num,
            test_name=test_name,
            status=TestStatus.ERROR,
            output_count=0,
            expected_count=0,
            matches=0,
            mismatches=0,
            error_message=f"Comparison error: {str(e)}",
            duration=time.time() - start_time
        )

    duration = time.time() - start_time

    if output_count != expected_count:
        status = TestStatus.FAILED
        error_msg = f"Size mismatch: got {output_count}, expected {expected_count}"
    elif len(mismatches) > 0:
        status = TestStatus.FAILED
        error_msg = f"{len(mismatches)} value mismatches"
    else:
        status = TestStatus.PASSED
        error_msg = ""

    result = TestResult(
        test_num=test_num,
        test_name=test_name,
        status=status,
        output_count=output_count,
        expected_count=expected_count,
        matches=matches,
        mismatches=len(mismatches),
        error_message=error_msg,
        duration=duration
    )

    if status == TestStatus.PASSED:
        print(f"  ✓ PASSED ({matches}/{expected_count} values match)")
    else:
        print(f"  ✗ FAILED: {error_msg}")
        if mismatches and verbose:
            print(f"  First mismatches:")
            for idx, out_val, exp_val in mismatches[:5]:
                print(f"    Index {idx}: got 0x{out_val:02X}, expected 0x{exp_val:02X}")

    print(f"  Duration: {duration:.2f}s")

    try:
        do_file.unlink()
    except:
        pass

    return result


def print_summary(results: List[TestResult]) -> None:
    print("\n")
    print("="*80)
    print("                           TEST RESULTS SUMMARY")
    print("="*80)

    print(f"\n{'Test':<5} {'Name':<25} {'Status':<10} {'Match':<15} {'Duration':<10}")
    print("-"*70)

    passed = 0
    failed = 0
    errors = 0
    skipped = 0

    for r in results:
        if r.status == TestStatus.PASSED:
            passed += 1
            status_str = "\033[92mPASSED\033[0m"  # Green
        elif r.status == TestStatus.FAILED:
            failed += 1
            status_str = "\033[91mFAILED\033[0m"  # Red
        elif r.status == TestStatus.ERROR:
            errors += 1
            status_str = "\033[93mERROR\033[0m"   # Yellow
        else:
            skipped += 1
            status_str = "\033[90mSKIPPED\033[0m" # Gray

        match_str = f"{r.matches}/{r.expected_count}" if r.expected_count > 0 else "N/A"
        print(f"{r.test_num:<5} {r.test_name:<25} {status_str:<20} {match_str:<15} {r.duration:.2f}s")

        if r.error_message and r.status != TestStatus.PASSED:
            print(f"      └─ {r.error_message}")

    print("-"*70)
    print(f"\nTotal: {len(results)} tests | "
          f"\033[92m{passed} passed\033[0m | "
          f"\033[91m{failed} failed\033[0m | "
          f"\033[93m{errors} errors\033[0m | "
          f"\033[90m{skipped} skipped\033[0m")

    total_time = sum(r.duration for r in results)
    print(f"Total duration: {total_time:.2f}s")
    print("="*80)


def save_results_to_file(results: List[TestResult], output_path: Path) -> None:
    """Save test results to a file."""
    with open(output_path, 'w') as f:
        f.write("Convolution Accelerator Test Results\n")
        f.write("="*60 + "\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")

        passed = sum(1 for r in results if r.status == TestStatus.PASSED)
        failed = sum(1 for r in results if r.status == TestStatus.FAILED)
        errors = sum(1 for r in results if r.status == TestStatus.ERROR)

        f.write(f"Summary: {passed}/{len(results)} tests passed\n")
        f.write(f"  Passed:  {passed}\n")
        f.write(f"  Failed:  {failed}\n")
        f.write(f"  Errors:  {errors}\n\n")

        f.write("-"*60 + "\n")
        f.write(f"{'Test':<5} {'Name':<25} {'Status':<10} {'Match':<15}\n")
        f.write("-"*60 + "\n")

        for r in results:
            match_str = f"{r.matches}/{r.expected_count}" if r.expected_count > 0 else "N/A"
            f.write(f"{r.test_num:<5} {r.test_name:<25} {r.status.value:<10} {match_str:<15}\n")
            if r.error_message:
                f.write(f"      Error: {r.error_message}\n")

        f.write("-"*60 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Run convolution accelerator test cases",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python run_all_tests.py              # Run all tests
    python run_all_tests.py --test 1 2 3 # Run tests 1, 2, and 3
    python run_all_tests.py --verbose    # Show detailed output
    python run_all_tests.py --list       # List available tests
        """
    )

    parser.add_argument(
        '--test', '-t',
        type=int,
        nargs='+',
        help='Specific test numbers to run (1-10)'
    )

    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Show verbose output including simulation logs'
    )

    parser.add_argument(
        '--list', '-l',
        action='store_true',
        help='List all available test cases'
    )

    parser.add_argument(
        '--output', '-o',
        type=str,
        default='test_results.txt',
        help='Output file for test results (default: test_results.txt)'
    )

    args = parser.parse_args()

    if args.list:
        print("\nAvailable Test Cases:")
        print("-"*40)
        for num, name in TEST_CASES.items():
            print(f"  {num:2d}: {name}")
        print()
        return 0

    project_root = get_project_root()
    print(f"Project root: {project_root}")

    if args.test:
        test_nums = args.test
        invalid_tests = [t for t in test_nums if t not in TEST_CASES]
        if invalid_tests:
            print(f"Error: Invalid test numbers: {invalid_tests}")
            print(f"Valid test numbers are 1-{len(TEST_CASES)}")
            return 1
    else:
        test_nums = list(TEST_CASES.keys())

    print(f"\nWill run {len(test_nums)} test(s): {test_nums}")

    results = []
    for test_num in test_nums:
        result = run_test_case(project_root, test_num, args.verbose)
        results.append(result)

    print_summary(results)

    output_path = project_root / args.output
    save_results_to_file(results, output_path)
    print(f"\nResults saved to: {output_path}")

    all_passed = all(r.status == TestStatus.PASSED for r in results)
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())

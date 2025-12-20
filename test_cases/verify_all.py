#!/usr/bin/env python3
"""
Batch verification script for all convolution test cases.
Automatically finds and verifies all test cases in the directory.
"""

import sys
from pathlib import Path
from verify_convolution import main as verify_test


def find_test_cases(directory="."):
    """Find all test case prefixes in the directory."""
    test_cases = set()
    path = Path(directory)
    
    for config_file in path.glob("*_config.txt"):
        # Extract prefix (everything before _config.txt)
        prefix = config_file.stem.replace("_config", "")
        test_cases.add(prefix)
    
    return sorted(test_cases)


def main():
    """Run verification on all test cases."""
    print("=" * 70)
    print("Batch Convolution Test Verification")
    print("=" * 70)
    
    test_cases = find_test_cases()
    
    if not test_cases:
        print("\nNo test cases found!")
        return False
    
    print(f"\nFound {len(test_cases)} test case(s):")
    for tc in test_cases:
        print(f"  - {tc}")
    
    print("\n" + "=" * 70)
    
    results = {}
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n[{i}/{len(test_cases)}] Testing: {test_case}")
        print("-" * 70)
        
        try:
            result = verify_test(test_case)
            results[test_case] = result
        except Exception as e:
            print(f"\n❌ ERROR: {e}")
            results[test_case] = False
        
        print()
    
    # Summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    
    passed = sum(1 for r in results.values() if r)
    failed = len(results) - passed
    
    print(f"\nTotal Tests: {len(results)}")
    print(f"✓ Passed:    {passed}")
    print(f"❌ Failed:    {failed}")
    
    if failed > 0:
        print("\nFailed Tests:")
        for tc, result in results.items():
            if not result:
                print(f"  - {tc}")
    
    print("\n" + "=" * 70)
    
    return failed == 0


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

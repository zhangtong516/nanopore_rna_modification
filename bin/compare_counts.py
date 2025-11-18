#!/usr/bin/env python3
import sys

def main():
    if len(sys.argv) < 3:
        print("Usage: compare_counts.py <bam_count> <pod_count> [threshold_percent]", file=sys.stderr)
        sys.exit(2)
    bam = int(sys.argv[1])
    pod = int(sys.argv[2])
    thr_pct = float(sys.argv[3]) if len(sys.argv) > 3 else 5.0

    if pod == 0:
        # If POD5 count is zero, only acceptable if BAM is also zero
        diff_pct = 0.0 if bam == 0 else 100.0
        print(f"{diff_pct:.2f}")
        sys.exit(0 if bam == 0 else 1)

    diff_abs = abs(bam - pod)
    diff_pct = (diff_abs / pod) * 100.0

    # Print percentage for logging; exit non-zero if above threshold
    print(f"{diff_pct:.2f}")
    sys.exit(0 if diff_pct <= thr_pct else 1)

if __name__ == "__main__":
    main()
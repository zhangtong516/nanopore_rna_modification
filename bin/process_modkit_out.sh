#!/usr/bin/env bash
set -euo pipefail

# Usage: process_modkit_out.sh -c <min_cov> -r <min_rate_percent> <input_bed> <output_tsv>
# Defaults: cov=1, rate=0.0

cov=1
rate=0.0

print_usage() {
  echo "Usage: $(basename "$0") [-c min_cov] [-r min_rate_percent] <input_bed> <output_tsv> <cpus>" >&2
}

while getopts ":c:r:h" opt; do
  case "$opt" in
    c) cov="$OPTARG" ;;
    r) rate="$OPTARG" ;;
    h) print_usage; exit 0 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; print_usage; exit 2 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; print_usage; exit 2 ;;
  esac
done
shift $((OPTIND-1))

if [ "$#" -ne 2 ]; then
  print_usage
  exit 2
fi

input_file="$1"
output_file="$2"

if [ ! -f "$input_file" ]; then
  echo "ERROR: Input file not found: $input_file" >&2
  exit 1
fi

# Columns expected from ModKit bed (tab-separated):
# 1 chrom, 2 start, 3 end, 4 mod_motif (code,motif,offset), 5 cov, 6 strand,
# 7 start2, 8 end2, 9 color, 10 N_valid_cov, 11 modified_rate,
# 12 N_mod, 13 N_canonical, 14 N_other_mod, 15 N_delete, 16 N_fail, 17 N_diff, 18 N_nocall
# This script appends a 19th column 'modification' derived from the code in column 4.

zcat "$input_file"  | awk -v min_cov="$cov" -v min_rate="$rate" 'BEGIN {
  FS="\t"; OFS="\t";
  # mapping from code -> modification name
  code_map["a"] = "m6A";
  code_map["m"] = "m5C";
  code_map["17802"] = "pseU";
  code_map["17596"] = "inosine";
  code_map["69426"] = "2_Ome_A";
  code_map["19228"] = "2_Ome_C";
  code_map["19229"] = "2_Ome_G";
  code_map["19227"] = "2_Ome_U";
}

{
  # Extract code from mod_motif (format: code,motif,offset)
  split($4, arr, ",");
  code = (length(arr) >= 1 ? arr[1] : "");
  mod = (code in code_map ? code_map[code] : "other");

  cov = ($5+0);
  rate = ($11+0);

  # Filter by coverage and modified rate (percent)
  if (cov >= min_cov && rate >= min_rate) {
    print $0, mod;
  }
}
' | pigz -p $cpus > "$output_file"

echo "Processed ModKit output written to: $output_file"


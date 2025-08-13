#!/bin/bash

# Script to chunk FAST5/POD5 files for processing
# Usage: chunk_files.sh <input_dir> <samplename> <chunk_size>

input_dir="$1"
samplename="$2"
chunk_size="$3"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <input_dir> <samplename> <chunk_size>"
    exit 1
fi

echo "Chunking files for ${samplename}"
echo "Input directory: ${input_dir}"
echo "Chunk size: ${chunk_size}"

# Find all FAST5/POD5 files
find "${input_dir}/" -name "*.fast5" -o -name "*.pod5" > all_files.txt

# Check if we found any files
if [ ! -s all_files.txt ]; then
    echo "No FAST5/POD5 files found in ${input_dir}"
    touch chunk_empty.txt
    exit 0
fi

# Calculate chunk size (aim for ~2.5 hour processing time per chunk)
total_files=$(wc -l < all_files.txt)
echo "Found $total_files files for ${samplename}"

# Adjust chunk size based on file count (aim for chunks that process in ~2.5 hours)
if [ $total_files -le $chunk_size ]; then
    # If total files is less than chunk size, create single chunk
    cp all_files.txt chunk_001.txt
else
    # Calculate number of chunks needed
    num_chunks=$(( (total_files + chunk_size - 1) / chunk_size ))
    files_per_chunk=$(( (total_files + num_chunks - 1) / num_chunks ))
    
    echo "Creating $num_chunks chunks with ~$files_per_chunk files each"
    
    # Split files into chunks
    split -l $files_per_chunk -d -a 3 all_files.txt chunk_
    
    # Rename chunks with .txt extension
    for chunk in chunk_*; do
        if [[ ! $chunk =~ \.txt$ ]]; then
            mv "$chunk" "${chunk}.txt"
        fi
    done
fi

# List created chunks
echo "Created chunks:"
ls -la chunk_*.txt
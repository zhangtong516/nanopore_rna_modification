#!/bin/bash

# Example script to run the nanopore RNA modification pipeline

# Set input parameters
INPUT_SAMPLESHEET="/path/to/samplesheet.csv"
REFERENCE_GENOME="/path/to/reference_genome.fasta"
OUTPUT_DIR="./results"

# Create output directory
mkdir -p $OUTPUT_DIR

# Run the Nextflow pipeline
nextflow run main.nf --samplesheet $INPUT_SAMPLESHEET --reference_genome $REFERENCE_GENOME -resume  

echo "Pipeline completed. Results available in: $OUTPUT_DIR"
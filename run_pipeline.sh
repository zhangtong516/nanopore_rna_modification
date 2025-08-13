#!/bin/bash

# Example script to run the nanopore RNA modification pipeline
BASE_DIR="/home/users/astar/gis/zhangt/scratch/nanopore_rna_mod/nanopore_rna_modification"
# Set input parameters
INPUT_SAMPLESHEET=$1
REFERENCE_GENOME="/home/users/astar/gis/zhangt/scratch/reference/GRCh38/Homo_sapiens.GRCh38.dna.primary_assembly.fa"
OUTPUT_DIR="./results"

# Create output directory
mkdir -p $OUTPUT_DIR

# Run the Nextflow pipeline
nextflow run ${BASE_DIR}/main.nf -c ${BASE_DIR}/nextflow_charon.config \
        --samplesheet $INPUT_SAMPLESHEET \
        --reference_genome $REFERENCE_GENOME \
        -resume

echo "Pipeline completed. Results available in: $OUTPUT_DIR"

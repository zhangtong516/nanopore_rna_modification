# Nanopore RNA Modification Analysis Pipeline

A comprehensive Nextflow workflow for analyzing nanopore direct RNA sequencing data with focus on RNA modifications, polyA tail estimation, and read alignment. This pipeline is optimized for HPC environments with GPU time limits and supports chunked processing for large datasets.

## Features

- **Dorado SUP Basecalling**: High-accuracy basecalling with SUP models and integrated polyA estimation
- **RNA Modification Detection**: Comprehensive RNA modification calling (m5C, 2OmeC, m6A, m6A_DRACH, inosine, 2OmeA, pseU, 2OmeU, 2OmeG)
- **PolyA Tail Estimation**: Built-in Dorado polyA tail length analysis with detailed statistics
- **Read Alignment**: Splice-aware alignment with minimap2
- **Chunked Processing**: Automatic file chunking for GPU time-limited environments
- **Resume Capability**: Robust resume functionality for interrupted runs
- **Multi-sample Support**: Process multiple samples using samplesheet input
- **Comprehensive Reporting**: HTML reports with detailed statistics and visualizations

## Requirements

### Software Dependencies
- Nextflow (≥23.04.0)
- Docker or Singularity
- CUDA-capable GPU (for Dorado basecalling)
- SLURM job scheduler (for HPC environments)

### Hardware Recommendations
- **CPU**: 16+ cores
- **RAM**: 64+ GB
- **GPU**: NVIDIA GPU with 8+ GB VRAM
- **Storage**: 1+ TB free space for ~20M reads

## Quick Start

### 1. Clone the repository
```bash
git clone <repository-url>
cd nanopore_rna_modification
```

### 2. Set up the environment
```bash
conda env create -f environment.yml
conda activate nanopore-rna-mod
```

### 3. Prepare input data

#### Option A: Single Sample (Legacy)
- FAST5 or POD5 files in a directory
- Reference genome FASTA file

#### Option B: Multiple Samples (Recommended)
Create a samplesheet.csv file:
```csv
samplename,input_dir
sample1,/path/to/sample1/fast5_files
sample2,/path/to/sample2/fast5_files
sample3,/path/to/sample3/pod5_files
```

### 4. Run the pipeline

#### For multiple samples (recommended):
```bash
nextflow run main.nf \
    --samplesheet samplesheet.csv \
    --reference_genome /path/to/genome.fasta \
    --output_dir ./results
```

#### For single sample (legacy):
```bash
nextflow run main.nf \
    --input_dir /path/to/fast5_files \
    --reference_genome /path/to/genome.fasta \
    --output_dir ./results
```

#### Using the provided script:
```bash
# Edit run_pipeline.sh with your paths
./run_pipeline.sh
```

### 5. Resume interrupted runs
If your run is interrupted (e.g., due to GPU time limits), simply add `-resume`:
```bash
nextflow run main.nf \
    --samplesheet samplesheet.csv \
    --reference_genome /path/to/genome.fasta \
    --output_dir ./results \
    -resume
```

## Configuration

### GPU Time Limits
The pipeline is designed to work with HPC GPU time limits (e.g., 3 hours). Key configurations:

- **Chunk Size**: Adjust `params.chunk_size` in nextflow.config (default: 500 files per chunk)
- **Time Limit**: Each chunk is set to complete within 2h 45m
- **GPU Partition**: Configure `clusterOptions` for your HPC setup

### Dorado Models
The pipeline includes pre-configured Dorado models in `resources/dorado_models/`:
- Base models: `rna004_130bps_sup@v5.2.0`
- Modification models: Various RNA modification-specific models

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--samplesheet` | null | CSV file with sample information |
| `--reference_genome` | null | Reference genome FASTA file |
| `--output_dir` | ./results | Output directory |
| `--dorado_model` | rna004_130bps_sup@v3.0.1 | Dorado basecalling model |
| `--dorado_mods` | m5C,2OmeC,m6A,... | RNA modifications to detect |
| `--threads` | 8 | Number of CPU threads |
| `--chunk_size` | 500 | Files per processing chunk |
| `--min_qscore` | 7 | Minimum quality score |
| `--kit_name` | SQK-RNA004 | Sequencing kit name |

## Output Structure

### For single samples:
```plain text
results/
├── basecalling/
│   ├── basecalled.bam
│   ├── basecalled.fastq.gz
│   └── sequencing_summary.txt
├── alignment/
│   ├── aligned.bam
│   ├── aligned.bam.bai
│   └── alignment_stats.txt
├── polya/
│   ├── polya_results.tsv
│   └── polya_summary.txt
├── modifications/
│   ├── modifications.bed
│   └── modification_summary.txt
└── reports/
    ├── final_report.html
    ├── nextflow_report.html
    └── timeline.html
```


### For chunked processing: 
```plain text
results/
├── sample1/
│   ├── basecalling/
│   ├── alignment/
│   ├── polya/
│   ├── modifications/
│   └── reports/
├── sample2/
├── sample3/
└── ...
```


## Troubleshooting

### Common Issues

1. **GPU Time Limit Exceeded**
   - The pipeline automatically chunks files to fit within time limits
   - Use `-resume` to continue from where it left off
   - Adjust `chunk_size` parameter if needed

2. **Out of Memory**
   - Reduce `chunk_size` parameter
   - Increase memory allocation in nextflow.config

3. **No GPU Available**
   - Dorado will automatically fall back to CPU (slower)
   - Ensure GPU partition is correctly configured

4. **Resume Not Working**
   - Check that work directory is intact
   - Ensure same parameters are used
   - Use absolute paths for input files

### Performance Optimization

- **Chunk Size**: Smaller chunks = more jobs but better parallelization
- **GPU Memory**: Ensure sufficient GPU memory for your chunk size
- **Storage**: Use fast storage (SSD) for work directory
- **Network**: Minimize network I/O for large datasets

## Advanced Usage

### Custom Dorado Models
To use custom Dorado models:
1. Place models in `resources/dorado_models/`
2. Update `params.dorado_rna_model` in nextflow.config

### HPC Configuration
For different HPC systems, modify the `process` section in nextflow.config:
```nextflow
process {
    executor = 'slurm'
    clusterOptions = '-V --partition=gpu4w --gres=gpu:1'
    // ... other configurations
}
```

### Resource Monitoring
Monitor resource usage through:
- Nextflow timeline report
- SLURM job monitoring
- GPU utilization (nvidia-smi)


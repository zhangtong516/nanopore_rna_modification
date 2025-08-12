#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Import modules
include { CHUNK_FILES } from './modules/chunk_files'
include { DORADO_BASECALL } from './modules/dorado_basecall'
include { MERGE_CHUNKS } from './modules/merge_chunks'
include { MINIMAP2_ALIGNMENT } from './modules/minimap2_alignment'
include { MODIFICATION_ANALYSIS } from './modules/modification_analysis'
include { GENERATE_REPORT } from './modules/generate_report'

// Define parameters
params.samplesheet = null
params.output_dir = "./results"
params.reference_genome = null
params.dorado_model = "rna004_130bps_sup@v3.0.1"
params.dorado_mods = "m5C,2OmeC,m6A,m6A_DRACH,inosine,2OmeA,pseU,2OmeU,2OmeG"
params.threads = 8
params.chunk_size = 500  // Adjust based on your processing speed and file sizes
params.help = false

// Help message
if (params.help) {
    log.info """
    Nanopore RNA Modification Analysis Pipeline (Chunked for GPU Time Limits)
    ========================================================================
    
    Usage:
        nextflow run main.nf --samplesheet <path> --reference_genome <path> [options]
    
    Required arguments:
        --samplesheet       CSV file with columns: samplename,input_dir
        --reference_genome  Path to reference genome FASTA file
    
    Optional arguments:
        --output_dir        Output directory (default: ./results)
        --dorado_model      Dorado basecalling model (default: rna004_130bps_sup@v3.0.1)
        --dorado_mods       RNA modifications to call (default: m5C,2OmeC,m6A,m6A_DRACH,inosine,2OmeA,pseU,2OmeU,2OmeG)
        --threads           Number of threads (default: 8)
        --chunk_size        Files per chunk (default: 500)
        --help              Show this help message
        
    Resume after interruption:
        nextflow run main.nf --samplesheet <path> --reference_genome <path> -resume
        
    Samplesheet format:
        samplename,input_dir
        sample1,/path/to/sample1/fast5_files
        sample2,/path/to/sample2/fast5_files
    """
    exit 0
}

// Validate required parameters
if (!params.samplesheet) {
    error "Please specify samplesheet with --samplesheet"
}
if (!params.reference_genome) {
    error "Please specify reference genome with --reference_genome"
}

// Function to parse samplesheet
def parse_samplesheet(samplesheet_path) {
    def samples = []
    def lines = file(samplesheet_path).readLines()
    
    // Skip header line
    for (int i = 1; i < lines.size(); i++) {
        def fields = lines[i].split(',')
        if (fields.size() >= 2) {
            def samplename = fields[0].trim()
            def input_dir = fields[1].trim()
            samples.add([samplename, input_dir])
        }
    }
    return samples
}

// Define workflow
workflow {
    // Parse samplesheet and create input channels
    def samples = parse_samplesheet(params.samplesheet)
    
    sample_ch = Channel.fromList(samples)
        .map { samplename, input_dir -> 
            tuple(samplename, file(input_dir, type: 'dir'))
        }
    
    reference_ch = Channel.fromPath(params.reference_genome)
    
    // Chunk files for each sample
    CHUNK_FILES(sample_ch)
    
    // Flatten chunks and add chunk IDs
    chunked_files = CHUNK_FILES.out.file_chunks
        .transpose()
        .map { samplename, chunk_file -> 
            def chunk_id = chunk_file.name.replaceAll(/chunk_|\.txt/, '')
            tuple(samplename, chunk_file, chunk_id)
        }
    
    // Process each chunk with Dorado
    DORADO_BASECALL(chunked_files)
    
    // Group chunks by sample for merging
    grouped_chunks = DORADO_BASECALL.out.basecalled_bam
        .groupTuple(by: 0)
        .map { samplename, bam_files -> 
            tuple(samplename, bam_files.flatten())
        }
    
    // Merge chunks back together
    MERGE_CHUNKS(grouped_chunks)
    
    // Continue with downstream analysis using merged files
    MINIMAP2_ALIGNMENT(
        MERGE_CHUNKS.out.basecalled_fastq,
        reference_ch
    )
    
    MODIFICATION_ANALYSIS(
        MERGE_CHUNKS.out.basecalled_bam,
        MINIMAP2_ALIGNMENT.out.aligned_bam,
        reference_ch
    )
    
    GENERATE_SUMMARY(MERGE_CHUNKS.out.basecalled_bam)
    // Collect all outputs for report generation
    summary_ch = MERGE_CHUNKS.out.summary.collect()
    polya_summary_ch = MERGE_CHUNKS.out.polya_summary.collect()
    alignment_stats_ch = MINIMAP2_ALIGNMENT.out.alignment_stats.collect()
    mod_summary_ch = MODIFICATION_ANALYSIS.out.mod_summary.collect()
    
    summary_ch = MERGE_CHUNKS.out.summary.join(
        MERGE_CHUNKS.out.polya_summary
    ).join(
        MODIFICATION_ANALYSIS.out.mod_summary
    ).join(
        MINIMAP2_ALIGNMENT.out.alignment_stats
    )

    GENERATE_REPORT(summary_ch) 
}

workflow.onComplete {
    log.info "Pipeline completed at: ${new Date()}"
    log.info "Results saved to: ${params.output_dir}"
    log.info "To resume an interrupted run, use: nextflow run main.nf -resume"
}
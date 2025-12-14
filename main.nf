#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Import modules
include { CHUNK_FILES } from './modules/chunk_files'
include { DORADO_BASECALL } from './modules/dorado_basecall'
include { VALIDATE_READ_COUNTS } from './modules/validate_read_counts'
include { MERGE_CHUNKS } from './modules/merge_chunks'
include { DORADO_ALIGNER } from './modules/dorado_aligner' 
include { MODIFICATION_ANALYSIS } from './modules/modification_analysis'
include { MODIFICATION_ANNOTATION } from './modules/modification_annotation'
include { GENERATE_REPORT } from './modules/generate_report'

// Define parameters
params.samplesheet = null
params.output_dir = "./results"
params.reference_genome = null
params.chunk_size = 20  // Adjust based on your processing speed and file sizes
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
        --dorado_model      Dorado basecalling model (default: sup)
        --dorado_mods       RNA modifications to call (default: m5C,2OmeC,m6A,m6A_DRACH,inosine,2OmeA,pseU,2OmeU,2OmeG)
        --threads           Number of threads (default: 8)
        --chunk_size        Files per chunk (default: 20)
        --help              Show this help message
        
    Resume after interruption:
        nextflow run main.nf --samplesheet <path> --reference_genome <path> -resume
        
    Samplesheet format:
        samplename,input_dir
        sample1,/path/to/sample1/pod5/
        sample2,/path/to/sample2/pod5/
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
    // Aggregate multiple input_dir entries per samplename
    def sampleDirs = [:].withDefault { [] }
    def lines = new File(samplesheet_path).readLines()

    // Skip header line
    for (int i = 1; i < lines.size(); i++) {
        def fields = lines[i].split(',')
        if (fields.size() >= 2) {
            def samplename = fields[0].trim()
            def input_dir = fields[1].trim()
            if (input_dir) {
                sampleDirs[samplename] << input_dir
            }
        }
    }

    // Return list of [samplename, csv_of_dirs]
    def samples = []
    sampleDirs.each { name, dirs ->
        def csv = dirs.join(',')
        samples.add([name, csv])
    }
    return samples
}

// Define workflow
workflow {
    // Parse samplesheet and create input channels
    def samples = parse_samplesheet(params.samplesheet)
    
    sample_ch = Channel.fromList(samples)
        .map { samplename, input_dirs_csv -> 
            // Pass comma-separated directories as value; CHUNK_FILES will expand
            tuple(samplename, input_dirs_csv)
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

    // Pair chunk file lists with basecalled BAMs for validation
    keyed_files = chunked_files
        .map { s, file_list, id -> tuple([s, id], file_list) }
    
    keyed_bams = DORADO_BASECALL.out.basecalled_bam
        .map { s, bam, id -> tuple([s, id], bam) }
    
    paired_for_validation = keyed_files
        .join(keyed_bams)
        .map { key, file_list, bam ->
            def samplename = key[0]
            def chunk_id   = key[1]
            tuple(samplename, file_list, chunk_id, bam)
        }

    // Validate read counts (POD5 vs BAM) per chunk; fail if >5% difference
    VALIDATE_READ_COUNTS(paired_for_validation)

    // Process alignment for each chunk 
    DORADO_ALIGNER(
        DORADO_BASECALL.out.basecalled_bam.combine(reference_ch)
    )
    
    // Group chunks by sample for merging
    grouped_chunks = DORADO_ALIGNER.out.aligned_bam
        .groupTuple(by: 0)
        .map { samplename, bam_files, chunk_ids -> 
            tuple(samplename, bam_files.flatten())
        }
    
    // Merge chunks back together
    MERGE_CHUNKS(grouped_chunks)
    
    // Modification analysis (produce ModKit bed)
    MODIFICATION_ANALYSIS(
        MERGE_CHUNKS.out.merged_aligned_bam.combine(reference_ch) 
    )

    // Annotation and summary generation as separate module
    MODIFICATION_ANNOTATION(
        MODIFICATION_ANALYSIS.out.modifications_bed
    )

    // Collect all outputs for report generation
    summary_ch = MERGE_CHUNKS.out.summary.join(
        MERGE_CHUNKS.out.polya_summary
    ).join(
        MODIFICATION_ANNOTATION.out.mod_summary
    ).join(
        MERGE_CHUNKS.out.alignment_stats
    )

    GENERATE_REPORT(summary_ch) 
}

workflow.onComplete {
    log.info "Pipeline completed at: ${new Date()}"
    log.info "Results saved to: ${params.output_dir}"
    log.info "To resume an interrupted run, use: nextflow run main.nf -resume"
}

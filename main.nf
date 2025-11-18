#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Import modules
include { CHUNK_FILES } from './modules/chunk_files'
include { DORADO_BASECALL } from './modules/dorado_basecall'
include { MERGE_CHUNKS } from './modules/merge_chunks'
include { DORADO_ALIGNER } from './modules/dorado_aligner' 
include { MODIFICATION_ANALYSIS } from './modules/modification_analysis'
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

    // Pair chunk file lists with basecalled BAMs for validation
    paired_for_validation = Channel
        .from(
            chunked_files.map { s, file_list, id -> tuple(tuple(s,id), file_list) },
            DORADO_BASECALL.out.basecalled_bam.map { s, bam, id -> tuple(tuple(s,id), bam) }
        )
        .join()
        .map { key, file_list, bam ->
            def (samplename, chunk_id) = key
            tuple(samplename, file_list, chunk_id, bam)
        }

    // Validate read counts (POD5 vs BAM) per chunk; fail if >5% difference
    VALIDATE_READ_COUNTS(paired_for_validation)

    // Process alignment for each chunk using validated BAMs
    DORADO_ALIGNER(
        VALIDATE_READ_COUNTS.out.validated_bam,
        reference_ch
    )
    
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
    
    // Modification analysis
    MODIFICATION_ANALYSIS(
        MERGE_CHUNKS.out.merged_aligned_bam,
        reference_ch
    )

    // Collect all outputs for report generation
    summary_ch = MERGE_CHUNKS.out.summary.join(
        MERGE_CHUNKS.out.polya_summary
    ).join(
        MODIFICATION_ANALYSIS.out.mod_summary
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
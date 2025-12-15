process DORADO_ALIGNER {
    tag "Read alignment with Dorado aligner"
    cpus params.threads
    memory '32 GB'
    
    // publishDir "${params.output_dir}/alignment",  mode: 'copy' 
    
    input:
    tuple val(samplename), path(basecalled_bam), val(chunk_id), path(reference_genome)
    
    output:
    tuple val(samplename), path("${samplename}_chunk_${chunk_id}_aligned.bam"), val(chunk_id), emit: aligned_bam
    
    script:
    """
    # Use Dorado aligner to align the basecalled BAM directly
    # This preserves all modification information from basecalling
    ${params.dorado} aligner \
        ${reference_genome} \
        ${basecalled_bam} \
        --threads ${params.threads} \
        --mm2-opts '-x splice -k 14' > ${samplename}_chunk_${chunk_id}_aligned.bam
    """
}
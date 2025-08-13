process MINIMAP2_ALIGNMENT {
    tag "Read alignment with minimap2"
    cpus params.threads
    memory '32 GB'
    
    storeDir "${params.output_dir}/alignment"
    
    input:
    tuple val(samplename), path(basecalled_fastq)
    path reference_genome
    
    output:
    tuple val(samplename), path("${samplename}_aligned.bam"), emit: aligned_bam
    tuple val(samplename), path("${samplename}_aligned.bam.bai"), emit: aligned_bai 
    tuple val(samplename), path("${samplename}_alignment_stats.txt"), emit: alignment_stats
    
    script:
    """
    # Index reference genome if needed
    if [ ! -f ${reference_genome}.mmi ]; then
        ${params.minimap2} -d ${reference_genome}.mmi ${reference_genome}
    fi
    
    # Align reads using minimap2 with RNA-specific parameters
    ${params.minimap2} -ax splice \
        -uf \
        -k14 \
        -t ${params.threads} \
        ${reference_genome} \
        ${basecalled_fastq} | \
    ${params.samtools} sort -@ ${params.threads} -o ${samplename}_aligned.bam -
    
    # Index the BAM file
    ${params.samtools} index aligned.bam
    
    # Generate alignment statistics
    ${params.samtools} flagstat ${samplename}_aligned.bam > ${samplename}_alignment_stats.txt
    ${params.samtools} stats ${samplename}_aligned.bam >> ${samplename}_alignment_stats.txt
    """
}
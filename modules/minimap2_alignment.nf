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
        minimap2 -d ${reference_genome}.mmi ${reference_genome}
    fi
    
    # Align reads using minimap2 with RNA-specific parameters
    minimap2 -ax splice \
        -uf \
        -k14 \
        -t ${params.threads} \
        ${reference_genome} \
        ${basecalled_fastq} | \
    samtools sort -@ ${params.threads} -o ${samplename}_aligned.bam -
    
    # Index the BAM file
    samtools index aligned.bam
    
    # Generate alignment statistics
    samtools flagstat ${samplename}_aligned.bam > ${samplename}_alignment_stats.txt
    samtools stats ${samplename}_aligned.bam >> ${samplename}_alignment_stats.txt
    """
}
process MODIFICATION_ANALYSIS {
    tag "RNA modification analysis"
    cpus 4
    memory '16 GB'
    
    publishDir "${params.output_dir}/modifications",  mode: 'move' 
    
    input:
    tuple val(samplename), path(aligned_bam), path(reference_genome) 
    
    output:
    tuple val(samplename), path("${samplename}_modifications.bed.gz"), emit: modifications_bed
    path("${samplename}_modification_analysis.log"), emit: modkit_log 

    
    script:
    """
    # Extract modification calls from Dorado BAM
    # Use modkit to extract and analyze modifications
    ${params.samtools} index -@ ${task.cpus} ${aligned_bam}
    ${params.samtools} faidx $reference_genome

    ${params.modkit} pileup \
        --ref ${reference_genome} \
        --threads ${task.cpus} \
        --mod-threshold a:0.10 --mod-threshold 17802:0.10 --mod-threshold 17596:0.10 --mod-threshold 69426:0.10 \
        --mod-threshold m:0.10 --mod-threshold 19229:0.10 --mod-threshold 19227:0.10 --mod-threshold 19228:0.10 \
        --log-filepath ${samplename}_modification_analysis.log \
        --motif A 0 --motif T 0 --motif C 0 --motif G 0 \
        ${aligned_bam} ${samplename}_modifications.bed 
    pigz -p ${task.cpus} ${samplename}_modifications.bed  
    
    # Annotation and summary moved to separate module (MODIFICATION_ANNOTATION)
    """
}

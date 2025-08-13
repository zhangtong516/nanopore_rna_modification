process MODIFICATION_ANALYSIS {
    tag "RNA modification analysis"
    cpus 4
    memory '16 GB'
    
    storeDir "${params.output_dir}/modifications"
    
    input:
    tuple val(samplename), path(basecalled_bam), path(aligned_bam)
    path reference_genome
    
    output:
    tuple val(samplename), path("${samplename}_modifications.bed"), emit: modifications_bed
    tuple val(samplename), path("${samplename}_modification_summary.txt"), emit: mod_summary
    
    script:
    """
    # Extract modification calls from Dorado BAM
    # Use modkit to extract and analyze modifications
    
    # Extract modifications to bedMethyl format
    ${params.modkit} extract whole-genome \

        --cpg \
        --chh \
        --chg \
        ${basecalled_bam} \
        ${samplename}_modifications.bed \
        --ref ${reference_genome}
    
    # Generate modification summary
    echo "RNA Modification Analysis Summary" > ${samplename}_modification_summary.txt
    echo "================================" >> ${samplename}_modification_summary.txt
    echo "" >> ${samplename}_modification_summary.txt
    
    # Count modifications by type
    if [ -s ${samplename}_modifications.bed ]; then
        echo "Total modification sites: \$(wc -l < ${samplename}_modifications.bed)" >> ${samplename}_modification_summary.txt
        
        # Analyze modification frequencies
        awk 'BEGIN{OFS="\t"} {mod_type=\$4; freq[mod_type]++} END{for(m in freq) print m, freq[m]}' ${samplename}_modifications.bed | \
        sort -k2,2nr >> ${samplename}_modification_summary.txt
    else
        echo "No modifications detected" >> ${samplename}_modification_summary.txt  
    fi
    """
}
process MODIFICATION_ANNOTATION {
    tag "RNA modification annotation"
    cpus 2
    memory '4 GB'

    publishDir "${params.output_dir}/modifications",  mode: 'move'

    input:
    tuple val(samplename), path(modifications_bed)

    output:
    tuple val(samplename), path("${samplename}_modifications.anno.bed"), emit: modifications_anno_bed
    tuple val(samplename), path("${samplename}_modification_summary.txt"), emit: mod_summary

    script:
    """
    # Annotate ModKit bed with human-friendly modification names and filters
    ${projectDir}/bin/process_modkit_out.sh \
        -c 1 -r 0.0 \
        ${modifications_bed} \
        ${samplename}_modifications.anno.bed

    # Generate modification summary (count sites by motif code in original bed)
    echo "RNA Modification Analysis Summary" > ${samplename}_modification_summary.txt
    echo "================================" >> ${samplename}_modification_summary.txt
    echo "" >> ${samplename}_modification_summary.txt

    if [ -s ${modifications_bed} ]; then
        echo "Total modification sites: \$(wc -l < ${modifications_bed})" >> ${samplename}_modification_summary.txt
        awk 'BEGIN{OFS="\t"} {mod_type=\$4; freq[mod_type]++} END{for(m in freq) print m, freq[m]}' ${modifications_bed} | \
        sort -k2,2nr >> ${samplename}_modification_summary.txt
    else
        echo "No modifications detected" >> ${samplename}_modification_summary.txt
    fi
    """
}


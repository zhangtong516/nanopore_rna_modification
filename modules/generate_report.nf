process GENERATE_REPORT {
    tag "Generating final report"
    
    publishDir "${params.output_dir}/reports",  mode: 'move'
    
    input:
    tuple val(samplename), path(summary), path(polya_summary), path(mod_summary), path(alignment_stats)

    output:
    path "${samplename}_final_report.html", emit: report

    script:
    """
    python ${projectDir}/bin/generate_report.py \
        ${samplename} \
        ${summary} \
        ${polya_summary} \
        ${mod_summary} \
        ${alignment_stats}
    """
}
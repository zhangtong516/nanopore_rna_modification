process VALIDATE_READ_COUNTS {
    tag "Validate read counts for ${samplename} chunk ${chunk_id}"
    cpus 2
    memory '4 GB'
    time '2h'

    publishDir "${params.output_dir}/basecalling/${samplename}", mode: 'copy'

    input:
    tuple val(samplename), path(file_list), val(chunk_id), path(basecalled_bam)

    output:
    // Pass-through BAM only if validation passes
    tuple val(samplename), path(basecalled_bam), val(chunk_id), emit: validated_bam
    path("${samplename}_chunk_${chunk_id}_readcount_check.txt"), emit: check_log

    script:
    """
    set -euo pipefail

    # Count reads in BAM
    bam_count=\$(${params.samtools} view ${basecalled_bam} | grep -v "pi:Z" | wc -l )

    # Count reads in POD5/FAST5 using helper script
    pod_count=\$(python ${projectDir}/bin/check_read_counts.py "${file_list}")

    # Compute absolute difference
    diff_abs=\$(( bam_count > pod_count ? bam_count - pod_count : pod_count - bam_count ))

    # Compute percentage and validate against threshold (30%)
    diff_pct=\$(python ${projectDir}/bin/compare_counts.py "\${bam_count}" "\${pod_count}" "${params.max_diff_threshold}")
    status=\$?

    # Write check log
    {
      echo "Sample: ${samplename}"
      echo "Chunk ID: ${chunk_id}"
      echo "POD5/FAST5 reads: \${pod_count}"
      echo "Basecalled BAM reads: \${bam_count}"
      echo "Absolute difference: \${diff_abs}"
      echo "Difference percent: \${diff_pct}%"
    } > ${samplename}_chunk_${chunk_id}_readcount_check.txt

    # Enforce threshold
    if [ "\${status}" -ne 0 ]; then
      echo "ERROR: Read count difference exceeds ${params.max_diff_threshold}% for ${samplename} chunk ${chunk_id} (POD5=\${pod_count}, BAM=\${bam_count})" >&2
      exit 1
    fi

    # If we get here, validation passed; emit BAM tuple
    """
}

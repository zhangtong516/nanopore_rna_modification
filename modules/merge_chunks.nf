process MERGE_CHUNKS {
    tag "Merging chunks for ${samplename}"
    
    storeDir "${params.output_dir}/basecalling"
    
    input:
    tuple val(samplename), path(bam_files)
    
    output:
    tuple val(samplename), path("${samplename}_aligned.bam"), emit: merged_aligned_bam
    tuple val(samplename), path("${samplename}_sequencing_summary.txt"), emit: summary
    tuple val(samplename), path("${samplename}_polya_results.tsv"), emit: polya_results
    tuple val(samplename), path("${samplename}_polya_summary.txt"), emit: polya_summary
    
    script:
    """
    # Merge BAM files
    if [ \$(echo ${bam_files} | wc -w) -eq 1 ]; then
        # Single file, just copy
        cp ${bam_files} ${samplename}_aligned.bam
    else
        # Multiple files, merge
        samtools merge --threads ${task.cpus} ${samplename}_aligned_merged.bam ${bam_files} 
    fi

    samtools sort --threads ${task.cpus} ${samplename}_aligned_merged.bam -o ${samplename}_aligned.bam 
    rm ${samplename}_aligned_merged.bam
    
    # Generate sequencing summary
    ${params.samtools} stats ${samplename}_aligned.bam > ${samplename}_sequencing_summary.txt
    
    # Extract polyA tail lengths from pt:i tags in BAM file
    ${params.samtools} view ${samplename}_aligned.bam | \
    awk 'BEGIN{OFS="\t"; print "read_id", "polya_length", "read_length", "status"} 
         {read_id=\$1; read_len=length(\$10); 
          polya_len="NA"; status="not_found";
          # Look for pt:i tag in BAM
          for(i=12; i<=NF; i++) {
              if(\$i ~ /^pt:i:/) {
                  split(\$i, arr, ":"); 
                  polya_len=arr[3];
                  if(polya_len == -1) {
                      status="primer_not_found";
                  } else if(polya_len == 0) {
                      status="primer_found_no_estimate";
                  } else if(polya_len > 0) {
                      status="estimated";
                  }
                  break;
              }
          }
          print read_id, polya_len, read_len, status}' > ${samplename}_polya_results.tsv
    
    # Generate polyA summary statistics
    awk 'BEGIN{total=0; estimated=0; primer_not_found=0; primer_found_no_estimate=0; sum=0; min_len=999999; max_len=0}
         NR>1 {
             total++;
             if(\$4 == "estimated" && \$2 > 0) {
                 estimated++;
                 sum += \$2;
                 if(\$2 < min_len) min_len = \$2;
                 if(\$2 > max_len) max_len = \$2;
             } else if(\$4 == "primer_not_found") {
                 primer_not_found++;
             } else if(\$4 == "primer_found_no_estimate") {
                 primer_found_no_estimate++;
             }
         }
         END {
             print "PolyA Tail Length Analysis Summary (Dorado pt:i tags) ";
             print "====================================================================";
             print "Total reads processed:", total;
             print "Reads with polyA estimates:", estimated;
             print "Reads with primer not found (pt:i = -1):", primer_not_found;
             print "Reads with primer found but no estimate (pt:i = 0):", primer_found_no_estimate;
             print "Reads with no pt:i tag:", total - estimated - primer_not_found - primer_found_no_estimate;
             print "";
             if(estimated > 0) {
                 avg = sum / estimated;
                 print "Average polyA length:", avg;
                 print "Min polyA length:", min_len;
                 print "Max polyA length:", max_len;
                 print "";
                 print "PolyA length distribution:";
             } else {
                 print "No polyA tail lengths could be estimated";
             }
         }' ${samplename}_polya_results.tsv > ${samplename}_polya_summary.txt
    
    # Add distribution analysis
    if [ -s ${samplename}_polya_results.tsv ]; then 
        awk 'NR>1 && \$4=="estimated" && \$2>0 {
                 if(\$2 <= 20) short++;
                 else if(\$2 <= 50) medium++;
                 else if(\$2 <= 100) long++;
                 else very_long++;
             }
             END {
                 if(short+medium+long+very_long > 0) {
                     print "PolyA length categories:";
                     print "  Short (1-20 nt):", short+0;
                     print "  Medium (21-50 nt):", medium+0;
                     print "  Long (51-100 nt):", long+0;
                     print "  Very long (>100 nt):", very_long+0;
                 }
             }' ${samplename}_polya_results.tsv >> ${samplename}_polya_summary.txt
    fi
    """
}
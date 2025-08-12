process DORADO_BASECALL {
    tag "Basecalling with Dorado SUP + PolyA estimation - Chunk ${chunk_id}"
    cpus params.threads
    memory '32 GB'
    time '2h 30m'  // Set to 2h 30m to allow cleanup before 3h limit
    
    storeDir "${params.output_dir}/basecalling/${samplename}"
    
    input:
    tuple val(samplename), path(file_list), val(chunk_id)
    
    output:
    tuple val(samplename), path("${samplename}_chunk_${chunk_id}_basecalled.bam"), emit: basecalled_bam
    tuple val(samplename), path("${samplename}_chunk_${chunk_id}_basecalled.fastq.gz"), emit: basecalled_fastq
    tuple val(samplename), path("${samplename}_chunk_${chunk_id}_sequencing_summary.txt"), emit: summary
    tuple val(samplename), path("${samplename}_chunk_${chunk_id}_modification_calls.tsv"), emit: mod_calls
    tuple val(samplename), path("${samplename}_chunk_${chunk_id}_polya_results.tsv"), emit: polya_results
    tuple val(samplename), path("${samplename}_chunk_${chunk_id}_polya_summary.txt"), emit: polya_summary
    
    script:
    """
    # Create input file list for dorado
    mkdir -p input_files
    while IFS= read -r file; do
        if [ -f "\$file" ]; then
            ln -s "\$file" input_files/
        fi
    done < ${file_list}
    
    # Check if we have any files to process
    file_count=\$(find input_files -type l | wc -l)
    if [ \$file_count -eq 0 ]; then
        echo "No files found in chunk ${chunk_id}, creating empty outputs"
        touch ${samplename}_chunk_${chunk_id}_basecalled.bam
        touch ${samplename}_chunk_${chunk_id}_basecalled.fastq.gz
        echo "No files processed in chunk ${chunk_id}" > ${samplename}_chunk_${chunk_id}_sequencing_summary.txt
        touch ${samplename}_chunk_${chunk_id}_modification_calls.tsv
        echo -e "read_id\tpolya_length\tread_length\tstatus" > ${samplename}_chunk_${chunk_id}_polya_results.tsv
        echo "No reads processed in chunk ${chunk_id}" > ${samplename}_chunk_${chunk_id}_polya_summary.txt
        exit 0
    fi
    
    # Check GPU availability
    nvidia-smi || echo "Warning: No GPU detected, falling back to CPU"
    
    # Run Dorado basecalling with SUP model, RNA modifications, and polyA estimation
    dorado basecaller \
        --modified-bases ${params.dorado_rna_model},${params.dorado_mods_models} \
        --device cuda:all \
        --estimate-poly-a \
        --min-qscore ${params.min_qscore} \
        --kit-name ${params.kit_name} \
        --emit-moves \
        input_files/ \
        > ${samplename}_chunk_${chunk_id}_basecalled.bam
    
    # Convert to FASTQ for downstream analysis
    samtools fastq ${samplename}_chunk_${chunk_id}_basecalled.bam | gzip > ${samplename}_chunk_${chunk_id}_basecalled.fastq.gz
    
    # Generate sequencing summary
    samtools stats ${samplename}_chunk_${chunk_id}_basecalled.bam > ${samplename}_chunk_${chunk_id}_sequencing_summary.txt
    
    # Extract modification calls to separate file
    samtools view -h ${samplename}_chunk_${chunk_id}_basecalled.bam | \
    awk '/^@/ {print; next} {if(\$0 ~ /MM:Z:/ || \$0 ~ /ML:B:/) print}' | \
    samtools view -bS - | \
    samtools view - | \
    cut -f1,3,4,12- | \
    grep -E "MM:Z:|ML:B:" > ${samplename}_chunk_${chunk_id}_modification_calls.tsv || touch ${samplename}_chunk_${chunk_id}_modification_calls.tsv
    
    # Extract polyA tail lengths from pt:i tags in BAM file
    samtools view ${samplename}_chunk_${chunk_id}_basecalled.bam | \
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
          print read_id, polya_len, read_len, status}' > ${samplename}_chunk_${chunk_id}_polya_results.tsv
    
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
             print "PolyA Tail Length Analysis Summary (Dorado pt:i tags) - Chunk ${chunk_id}";
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
         }' ${samplename}_chunk_${chunk_id}_polya_results.tsv > ${samplename}_chunk_${chunk_id}_polya_summary.txt
    
    # Add distribution analysis
    if [ -s ${samplename}_chunk_${chunk_id}_polya_results.tsv ]; then 
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
             }' ${samplename}_chunk_${chunk_id}_polya_results.tsv >> ${samplename}_chunk_${chunk_id}_polya_summary.txt
    fi
    """
}
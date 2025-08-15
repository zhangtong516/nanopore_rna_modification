process DORADO_BASECALL {
    tag "Basecalling with Dorado SUP + PolyA estimation - Chunk ${chunk_id}"
    cpus params.threads
    memory '32 GB'
    time '2h 30m'  // Set to 2h 30m to allow cleanup before 3h limit
    
    storeDir "${params.output_dir}/basecalling/${samplename}"
    
    input:
    tuple val(samplename), path(file_list), val(chunk_id)
    
    output:
    tuple val(samplename), path("${samplename}_chunk_${chunk_id}_basecalled.bam"), val(chunk_id), emit: basecalled_bam
    
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
        exit 0
    fi
    
    # Check GPU availability
    nvidia-smi || echo "Warning: No GPU detected, falling back to CPU"
    
    # Run Dorado basecalling with SUP model, RNA modifications, and polyA estimation
    ${params.dorado} basecaller ${params.dorado_model},${params.dorado_mods_models} \
        --device cuda:0 \
        --estimate-poly-a \
        --min-qscore ${params.min_qscore} \
        --emit-moves \
        --batchsize 0 \
        input_files/ \
        > ${samplename}_chunk_${chunk_id}_basecalled.bam
        
    """
}
process PREPARE_INPUT {
    tag "Preparing input files"
    
    input:
    tuple val(samplename), path(input_dir)
    
    output:
    tuple val(samplename), path("${samplename}_file_list.txt"), emit: file_list

    
    script:
    """
    find ${input_dir} -name "*.fast5" -o -name "*.pod5" | head -n ${params.chunk_size} > ${samplename}_file_list.txt
    if [ ! -s ${samplename}_file_list.txt ]; then
        echo "No FAST5 or POD5 files found in ${input_dir}"
        exit 1
    fi
    """
}
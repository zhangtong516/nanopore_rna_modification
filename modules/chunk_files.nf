process CHUNK_FILES {
    tag "Chunking files for ${samplename}"
    
    input:
    // input_dirs is a comma-separated list of directories
    tuple val(samplename), val(input_dirs)
    
    output:
    tuple val(samplename), path("chunk_*.txt"), emit: file_chunks
    
    script:
    """
    bash ${projectDir}/bin/chunk_files.sh "${input_dirs}" "${samplename}" "${params.chunk_size}"
    """
} 

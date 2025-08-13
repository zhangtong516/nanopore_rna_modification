process CHUNK_FILES {
    tag "Chunking files for ${samplename}"
    
    input:
    tuple val(samplename), path(input_dir)
    
    output:
    tuple val(samplename), path("chunk_*.txt"), emit: file_chunks
    
    script:
    """
    bash ${projectDir}/bin/chunk_files.sh "${input_dir}" "${samplename}" "${params.chunk_size}"
    """
}
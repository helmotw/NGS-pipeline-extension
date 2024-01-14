params.output_dir = 'outputs'
params.input_dir = 'raw_data'

Channel
    .fromFilePairs("${params.input_dir}/SRR26630744_{1,2}.fastq", size: 2)
    .set { raw_data_channel }

raw_data_channel.view { it -> println("Channel output: ${it}") }


check_tool = { tool ->
    return """
        if ! command -v $tool &> /dev/null
        then
            echo "$tool is not installed. Please install it and make sure it's in your PATH."
            exit 1
        fi
    """
}

beforeScript:
  input_dir = params.input_dir
  output_dir = params.output_dir
  if (!file(output_dir).exists()) {
    script:
      """
      mkdir -p ${output_dir}
      """
  }

script:
  check_tool("fastp")
  check_tool("spades")
  check_tool("quast")

process fastp_process {
    label 'fastp'
    publishDir "${output_dir}/trimmed_reads", mode: 'copy'
    input:
        tuple val(sampleName), path(reads)
    output:
        path "trimmed_*_*.fastq"
    script:
    """
    set -euo pipefail
    echo "Starting fastp processing for ${sampleName}..."
    fastp --in1 ${reads[0]} --in2 ${reads[1]} --out1 trimmed_${sampleName}_1.fastq --out2 trimmed_${sampleName}_2.fastq ...
    """
}

process spades_process {
  label 'spades'
  publishDir "${output_dir}/assembled_genome", mode: 'copy'
  input:
    path reads 
  output:
    path "scaffolds.fasta"
  cpus 4
  memory '8 GB'
  script:
    """
    set -euo pipefail
    echo "Starting SPAdes genome assembly..."
    spades.py -1 ${reads[0]} -2 ${reads[1]} -o .
    echo "SPAdes genome assembly completed successfully."
    """
}

process quast_process {
  label 'quast'
  publishDir "${output_dir}/quast_output", mode: 'copy'
  input:
    path assembled_genome 
  output:
    path "outputs/quast_output/report.html"
  cpus 4
  memory '8 GB'
  script:
    """
    mkdir -p outputs/quast_output
    set -euo pipefail
    echo "Starting QUAST quality assessment..."
    quast.py scaffolds.fasta -o outputs/quast_output
    """
}

workflow {
    fastp_process(raw_data_channel)
    spades_process(fastp_process.out)
    quast_process(spades_process.out)
}


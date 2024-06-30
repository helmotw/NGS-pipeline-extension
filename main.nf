// Define input and output directory parameters
params.input_dir = 'raw_data'
params.tools_dir = 'tools' //Container location
params.sample_seed = 100
params.sample_percentage = 100

// Define a list of different trimming combinations for sequence processing
def trimmingCombinations = [
  "QualityTrim_Q25",
  "AdapterTrim_Q25",
  "LengthFilter_75",
  "ComplexityFilter",
  "SlidingWindow_4nt_q25",
  "QualitySlidingHybrid_Q25_4nt_q25", // QualityTrim_Q25 + SlidingWindow_4nt_q25
  "QualityAdapterHybrid_Q25", // QualityTrim_Q25 + AdapterTrim_Q25
  "LengthComplexityHybrid_75", // LengthFilter_75 + ComplexityFilter
  "SlidingComplexityHybrid_4nt_q25", // SlidingWindow_4nt_q25 + ComplexityFilter
  "AdapterSlidingHybrid_Q25_4nt_q25", // AdapterTrim_Q25 + SlidingWindow_4nt_q25
  "QualityLengthHybrid_Q25_75", // QualityTrim_Q25 + LengthFilter_75
  "QualityComplexityHybrid_Q25", // QualityTrim_Q25 + ComplexityFilter
  "AdapterLengthHybrid_Q25_75", // AdapterTrim_Q25 + LengthFilter_75
  "AdapterComplexityHybrid_Q25", // AdapterTrim_Q25 + ComplexityFilter
  "LengthSlidingHybrid_75_4nt_Q25", // LengthFilter_75 + SlidingWindow_4nt_q25
  "NoTrimming"
]

/* Create for input sampling
*/

  Channel
    .fromFilePairs("${params.input_dir}/*{1,2}.fastq")
    .set { seqtkInputChannel }

process seqtk_process {
  label 'seqtk'
  container "${params.tools_dir}/seqtk.sif"

  input:
    tuple val(sampleId), file(reads)

  output:
    tuple val(sampleId), file('sampled/*_{1,2}.fastq')

  script:
    """
    set -euo pipefail
    mkdir -p sampled
    seqtk sample -s${params.sample_seed} ${reads[0]} ${params.sample_percentage/100} > sampled/${reads[0].baseName}.fastq
    seqtk sample -s${params.sample_seed} ${reads[1]} ${params.sample_percentage/100} > sampled/${reads[1].baseName}.fastq
    """
}

process fastp_process {
  label 'fastp'
  tag "${trimParams}_${reads[0].getName()}"
  container "${params.tools_dir}/fastp.sif"

  input:
    tuple val(trimParams), file(reads)

  output:
    tuple val(trimParams), \
    path("${reads[0].simpleName}_${trimParams}.fastq"), \
    path("${reads[1].simpleName}_${trimParams}.fastq")



  script:
    String trimParamsStr = trimParams.toString().trim()
    def fastpCmd = "fastp --in1 ${reads[0]} --in2 ${reads[1]}"
    String outputFileName1 = "${reads[0].simpleName}_${trimParams}.fastq"
    String outputFileName2 = "${reads[1].simpleName}_${trimParams}.fastq"
    fastpCmd += " --out1 ${outputFileName1} --out2 ${outputFileName2}"

    String htmlReport = "${reads[0].simpleName}_${trimParams}.html"
    String jsonReport = "${reads[0].simpleName}_${trimParams}.json"
    fastpCmd += " --html ${htmlReport} --json ${jsonReport}"
    def parts = trimParamsStr.tokenize('_')

    def trimActionMap = [
    QualityTrim: { String q ->
      "--qualified_quality_phred ${q.replace('Q', '')}" 
    },
    AdapterTrim: { String q -> 
      "--detect_adapter_for_pe --qualified_quality_phred " +
      "${q.replace('Q', '')}" 
    },
    LengthFilter: { String length -> 
      "--length_required ${length}" 
    },
    ComplexityFilter: { _ -> 
      "--low_complexity_filter"
    },
    SlidingWindow: { String windowSize, String meanQuality -> 
      "--cut_right --cut_window_size ${windowSize.replace('nt', '')} " +
      "--cut_mean_quality ${meanQuality.replace('q', '')}" 
    },
    QualitySlidingHybrid: { String q, String windowSize, String meanQuality -> 
      "--cut_right --qualified_quality_phred ${q.replace('Q', '')} " +
      "--cut_window_size ${windowSize.replace('nt', '')} " +
      "--cut_mean_quality ${meanQuality.replace('q', '')}" 
    },
    QualityAdapterHybrid: { String q -> 
      "--detect_adapter_for_pe --qualified_quality_phred " +
      "${q.replace('Q', '')}" 
    },
    LengthComplexityHybrid: { String length -> 
      "--length_required ${length} --low_complexity_filter" 
    },
    SlidingComplexityHybrid: { String windowSize, String meanQuality -> 
      "--cut_right --cut_window_size ${windowSize.replace('nt', '')} " +
      "--cut_mean_quality ${meanQuality.replace('q', '')} " +
      "--low_complexity_filter" 
    },
    AdapterSlidingHybrid: { String q, String windowSize, String meanQuality -> 
      "--detect_adapter_for_pe --cut_right --cut_window_size " +
      "${windowSize.replace('nt', '')} --cut_mean_quality " +
      "${meanQuality.replace('q', '')} --qualified_quality_phred " +
      "${q.replace('Q', '')}" 
    },
    QualityLengthHybrid: { String q, String length -> 
      "--qualified_quality_phred ${q.replace('Q', '')} " +
      "--length_required ${length}" 
    },
    QualityComplexityHybrid: { String q -> 
      "--qualified_quality_phred ${q.replace('Q', '')} --low_complexity_filter" 
    },
    AdapterLengthHybrid: { String q, String length -> 
      "--detect_adapter_for_pe --qualified_quality_phred " +
      "${q.replace('Q', '')} --length_required ${length}" 
    },
    AdapterComplexityHybrid: { String q -> 
      "--detect_adapter_for_pe --qualified_quality_phred " +
      "${q.replace('Q', '')} --low_complexity_filter" 
    },
    LengthSlidingHybrid: { 
      String length, String windowSize, String meanQuality -> 
      "--length_required ${length} --cut_right --cut_window_size " +
      "${windowSize.replace('nt', '')} --cut_mean_quality " +
      "${meanQuality.replace('Q', '')}" 
    },
    NoTrimming: { _ -> 
      "--disable_adapter_trimming --disable_quality_filtering " +
      "--disable_length_filtering" 
    }
    ]

    trimActionMap.each { key, action ->
    if (trimParamsStr.startsWith(key)) {
        fastpCmd += " " + action(parts.drop(1))
        return
      }
    }

    """
    set -euo pipefail
    echo "Trimming parameters: ${trimParams}"
    if [ ${reads.size()} -ne 2 ]; then
      echo "Error: Expected two reads files, but got ${reads.size()}"
      exit 1
    fi
    ${fastpCmd}
    echo "fastp process for ${trimParams}_"\
    "${reads[0].getName()} completed successfully."
    """
}

process abyss_process {
    label 'abyss'
    container "${params.tools_dir}/abyss.sif"
    publishDir 'scaffolds_abyss', mode: 'copy'
    tag "${trimParams}"

    input:
    tuple val(trimParams), path(read1), path(read2)

    output:
    path "abyss_scaffolds_${trimParams}.fasta"

    script:
    """
    set -euo pipefail
    echo "Read1: ${read1}"
    echo "Read2: ${read2}"
    echo "Starting ABySS genome assembly for ${trimParams}..."
    abyss-pe k=96 B=2G name=abyss_output_${trimParams} in='${read1} ${read2}'
    mv abyss_output_${trimParams}-scaffolds.fa abyss_scaffolds_${trimParams}.fasta
    echo "ABySS genome assembly for ${trimParams} completed successfully."
    """
}

process clover_process {
  label 'clover'
  tag "${trimParams}"
  publishDir 'scaffolds_clover', mode: 'copy'

  input:
    tuple val(trimParams), path(read1), path(read2)  

  output:
    path "clover_scaffolds_${trimParams}.fasta"

  script:
    """
    set -euo pipefail
    echo "Read1: ${read1}"
    echo "Read2: ${read2}"
    echo "Starting Clover genome assembly for ${trimParams}..."
    clover.sif clover -k 50 -p 1 -i1 ${read1} -i2 ${read2} -is 300 -ml 500 -sp 0.3 -hp 0.8 -rp 0.8 -o clover_output_${trimParams} //use absolute path for this container
    mv clover_output_${trimParams}_scaffold.fasta clover_scaffolds_${trimParams}.fasta
    echo "Clover genome assembly for ${trimParams} completed successfully."
    """
}

process spades_process {
  label 'spades'
  tag "${trimParams}"
  container "${params.tools_dir}/spades.sif"
  publishDir 'scaffolds_spades', mode: 'copy'

  input:
    tuple val(trimParams), path(read1), path(read2)

  output:
    path "spades_scaffolds_${trimParams}.fasta"

  script:
    """
    set -euo pipefail
    echo "Read1: ${read1}"
    echo "Read2: ${read2}
    echo "Starting SPAdes genome assembly for ${trimParams}..."
    spades.py --isolate -1 ${read1} -2 ${read2} -o output_${trimParams}
    mv output_${trimParams}/scaffolds.fasta spades_scaffolds_${trimParams}.fasta
    echo "SPAdes genome assembly for ${trimParams} completed successfully."
    """
}

process quast_process {
  label 'quast'
  container "${params.tools_dir}/quast.sif"

  input:
    path genomes

  output:
    path "reports"

  script:
    """
    mkdir -p reports
    set -euo pipefail
    for genome in ${genomes}
    do
      genome_name=\$(basename \$genome .fasta)
      echo "Starting QUAST quality assessment for \$genome_name..."
      quast.py -o reports/output_\${genome_name} \${genome}
      mv reports/output_\${genome_name}/report.html \
        reports/report_\${genome_name}.html
      echo "QUAST quality assessment for \$genome_name completed."
    done
    """
}

workflow {
  seqtk_process(seqtkInputChannel)
    .map { sampleId, files -> 
      tuple(sampleId, files) 
    }
    .set { seqtkOutputChannel }

  Channel
    .from(trimmingCombinations)
    .combine(seqtkOutputChannel)
    .map { trimParams, sampleId, files -> 
      println("Trim Params: ${trimParams}, Files: ${files}") 
      tuple(trimParams, files) 
    }
    .set { trimmingChannel }

  fastp_process(trimmingChannel)
    .groupTuple()
    .set { fastpCollectChannel }

  spades_process(fastpCollectChannel)
    .collect()
    .set { spadesOutputChannel }

  abyss_process(fastpCollectChannel)
    .collect()
    .set { abyssOutputChannel }

  clover_process(fastpCollectChannel)
    .collect()
    .set { cloverOutputChannel }

  quastInputChannel = spadesOutputChannel
    .concat( cloverOutputChannel, abyssOutputChannel )

  quast_process(quastInputChannel)
}

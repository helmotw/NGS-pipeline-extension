// Define input and output directory parameters
params.input_dir = 'raw_data'

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

/* Create a channel with trimming combinations 
  and pair them with file pairs from the input directory
*/
Channel
  .from(trimmingCombinations)
  .combine(Channel.fromFilePairs("${params.input_dir}/*_{1,2}.fastq"))
  .map { trimParams, sampleId, files -> 
    println("Trim Params: ${trimParams}, Files: ${files}") 
    tuple(trimParams, files) 
  }
  .set { trimmingChannel }


process fastp_process {
  label 'fastp'
  tag "${trimParams}_${reads[0].getName()}"

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


process spades_process {
  label 'spades'
  tag "${trimParams}"

  input:
    tuple val(trimParams), path(read1), path(read2)
    
  output:
    path "scaffolds_${trimParams}.fasta"

  cpus 4
  memory '8 GB'

  script:
    """
    set -euo pipefail
    echo "Read1: ${read1}"
    echo "Read2: ${read2}"
    echo "Starting SPAdes genome assembly for ${trimParams}..."
    spades.py --isolate -1 ${read1} -2 ${read2} -o output_${trimParams}
    mv output_${trimParams}/scaffolds.fasta scaffolds_${trimParams}.fasta
    echo "SPAdes genome assembly for ${trimParams} completed successfully."
    """
}


process quast_process {
  label 'quast'

  input:
    path genomes

  output:
    path "reports"

  cpus 4
  memory '8 GB'

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
  fastp_process(trimmingChannel)
    .groupTuple()
    .set { fastpCollectChannel }

  spades_process(fastpCollectChannel)
    .collect()
    .set { quastInputChannel }

  quast_process(quastInputChannel)
}
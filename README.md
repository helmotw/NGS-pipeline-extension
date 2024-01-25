# NGS-QC-tools-pipeline

### Intro:
This repository contains a robust pipeline for genome assembly and quality assessment, designed to streamline the process of genomic data analysis. The pipeline integrates several key bioinformatics tools to ensure accurate and efficient genome assembly.

⚠️ GitHub has a strict limit of 100 MB per file and a recommended limit of 1 GB for the repository size. Therefore, the raw_data folder does not contain any FASTQ files, because they are several times the allowed-to-push file size on GitHub. 

However, the results folder stores examples of computational results in .tsv format after successful execution of a program pipeline in which various methods and parameters were applied to trim the sequenced raw NGS DNA data of the Mycobacterium tuberculosis molecule. 

To make it convenient to study all these reports in the future, the program [**MetricsExtractor.ipynb**](NGS-pipeline/MetricsExtractor.ipynb) was created.



## Key Features:

1. **Trimming Combinations**
_trimmingCombinations_: A list of different combinations for sequence processing, including quality trimming, adapter trimming, length filtering, complexity filtering, and various hybrids of these methods.

2. **The trimmingChannel:** A channel that pairs trimming parameters with file pairs, ready to be processed by downstream processes.

![NGS-QC-tools-pipeline](images/NGS-pipeline.drawio.png)

3. **Fastp Process:** This process uses fastp, a tool for fast and high-quality preprocessing of sequencing data. It takes paired-end reads and the trimming parameters as input and generates trimmed sequence files based on the specified parameters. The process dynamically constructs the fastp command based on the trimming combination provided, applying the relevant trimming options.

4. **SPAdes Assembly:** This process runs the SPAdes genome assembler on the trimmed reads to construct genome assemblies. It outputs the assembled scaffolds for each trimming parameter set.

5. **QUAST Quality Assessment:** This process performs quality assessment on the assembled genomes using QUAST. It generates reports for each assembly, providing insights into the quality and statistics of the assembled sequences.

6. **Workflow:** The workflow orchestrates the execution of these processes in a data-driven manner:
- _fastp_process_ is executed first, receiving combinations of trimming parameters and file pairs from _trimmingChannel_. The trimmed reads are then grouped by their trimming parameters and passed to the _spades_process_.
- _spades_process_ assembles the genomes from the trimmed reads and outputs the assembled scaffolds, which are collected and passed to the _quast_process_.
- _quast_process_ assesses the quality of each assembled genome and generates reports.
  
7. **Highlights of the Workflow:**
- _Dynamic Command Construction_: The script dynamically constructs commands for fastp based on the trimming strategies, making the workflow highly flexible and adaptable to various preprocessing needs.
- _Data-driven Execution_: The workflow's execution is driven by the available data and specified parameters, ensuring efficient and parallel processing of multiple samples and trimming strategies.
- _Scalability_: By leveraging Nextflow, the workflow can be easily scaled and executed across different computational environments, from local machines to high-throughput computing clusters and cloud environments.

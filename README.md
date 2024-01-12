# NGS-QC-tools-pipeline

This repository contains a robust pipeline for genome assembly and quality assessment, designed to streamline the process of genomic data analysis. The pipeline integrates several key bioinformatics tools to ensure accurate and efficient genome assembly.

⚠️ GitHub has a strict limit of 100 MB per file and a recommended limit of 1 GB for the repository size. Therefore, the raw_data folder does not contain any FASTQ files, because they are several times the allowed-to-push file size on GitHub.

## Key Features:

1. **Fastp Process:** Implements 'fastp' for initial data processing, ensuring high-quality read data by trimming adapters and filtering out low-quality reads.

2. **SPAdes Assembly:** Utilizes the SPAdes genome assembler, renowned for its efficacy in constructing high-quality genome assemblies from high-throughput sequencing data.

3. **QUAST Quality Assessment:** Incorporates QUAST for comprehensive evaluation of the assembled genome. This step provides detailed insights into various assembly metrics such as N50, GC content, total length, and the number of contigs.

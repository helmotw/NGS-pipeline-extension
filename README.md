# NGS-QC-tools-pipeline

### Intro:
This repository contains a robust pipeline for genome assembly and quality assessment, designed to streamline the process of genomic data analysis. The pipeline integrates several key bioinformatics tools to ensure accurate and efficient genome assembly.

⚠️ GitHub has a strict limit of 100 MB per file and a recommended limit of 1 GB for the repository size. Therefore, the raw_data folder does not contain any FASTQ files, because they are several times the allowed-to-push file size on GitHub. 

However, the results folder stores examples of computational results in .tsv format after successful execution of a program pipeline in which various methods and parameters were applied to trim the sequenced raw NGS DNA data of the Mycobacterium tuberculosis molecule. 

📈 To make it convenient to study all these reports in the future, the program [**MetricsExtractor.ipynb**](/MetricsExtractor.ipynb) was created.

💡 A detailed description of the software pipeline in the form of a PDF document written in academic English (and corresponding LaTeX files) can also be found in this repository. 


## Key Features:

1. **Trimming Combinations:**
_trimmingCombinations_: A list of different combinations for sequence processing, including quality trimming, adapter trimming, length filtering, complexity filtering, and various hybrids of these methods.

2. **The trimmingChannel:** A channel that pairs trimming parameters with file pairs, ready to be processed by downstream processes.

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

## Selection of trimming methods & the naming conventions:

The naming conventions used throughout the script are consistent and logical, making the code readable and understandable. Each name gives clear insight into what the variable, parameter, or process is intended for, which is crucial in complex bioinformatics workflows where clarity and precision are paramount. The naming strategy in this code aids in understanding the flow and purpose of different parts of the script, aligning well with best practices in coding for clarity, maintainability, and collaboration.

1. **Trimming Combinations:**
- The trimming combinations (e.g., _QualityTrim_Q25_, _AdapterTrim_Q25_, etc.) use a systematic approach that combines the type of trimming operation with specific parameters, separated by underscores (_).
- Type of Trimming: The first part of each name (e.g., _QualityTrim_, _AdapterTrim_) specifies the type of trimming operation, indicating what aspect of the sequence data is being trimmed (quality, adapter, etc.). When the program pipeline runs for the first time we use 5 different basic trimming methods with the most averaged parameters. Each trimming operation addresses different types of potential issues in sequencing data:
    - _Quality Trimming:_ Removes regions with low sequencing quality, which can improve the accuracy of downstream analyses
    - _Adapter Trimming:_ Removes adapter sequences that can interfere with read alignment and other analyses
    - _Length Filtering:_ Ensures that only reads of a certain length are kept, which can be crucial for certain types of analysis like assembly
    - _Complexity Filtering:_ Removes low complexity sequences that could be repetitive or non-informative
    - _Sliding Window Trimming:_ Applies quality trimming in a sliding window, offering a balance between quality control and retaining as much data as possible
- Parameters: Following the underscore, the parameters are specified, often with a prefix (e.g., Q25 for a quality threshold of 25, 75 for length filtering at 75 bases, 4nt for a window size of 4 nucleotides, q25 for а mean quality threshold inside the window of 25).
- Hybrids: Names like _QualityAdapterHybrid_Q25_ (containing the word _Hybrid_) suggest a combination of two trimming operations (in this case for example it's the _QualityTrim_Q25_ & the _AdapterTrim_Q25_), providing a clear indication of the processes involved. The number of unique combinations (where each pair consists of two different basic trimming options of the 5 described above excluding combining any trimming methods with themselves) according to the concept of combinations without repetition (also known as "combinations without replacement") is exactly 10. Different sequencing platforms and sample preparations can introduce various types of artifacts or biases in the data. Testing different combinations allows the pipeline to be adaptable to a wide range of data types and qualities.
- In total, we will be testing 15 different trimming methods during the first run of the program pipeline, and the 16th method is called _NoTrimming_, which, as its name suggests, tells us that no trimming is used in this case. This naming consistency has a huge effect during the execution of a program pipeline. Each piece of data can be traced through the pipeline, from the initial input to the final output, including intermediate steps. All the names of the trimming methods at each step are preserved, facilitating the reproduction of results, as each step's function and input/output relationships are clearly defined. In addition, researchers or future users of the pipeline can easily understand the workflow, modify it, or extend it due to the logical and transparent naming conventions.

Demonstration of naming consistency in data streams after the first run of the program pipeline:


![NGS-QC-tools-pipeline](images/NGS-pipeline.drawio.png)

2. **Channel and Process Definitions:**
- Channel: Used to create a stream of data. The naming within the channel operations (_trimmingChannel_, _fastpCollectChannel_, _quastInputChannel_) is indicative of their role in the workflow, specifying both the type of data they handle and their position or function within the pipeline.
- Process: Each process is named according to the primary tool or operation it performs (_fastp_process_, _spades_process_, _quast_process_), making it straightforward to understand their role within the workflow.
3. **Input and Output:**
- input and output declarations within processes are named to reflect the data they handle, with tuples and paths indicating the nature and format of the data (e.g., tuple val(trimParams), file(reads) for input and path("${reads[0].simpleName}_${trimParams}.fastq") for output).

cwlVersion: v1.0
class: Workflow


requirements:
  - class: StepInputExpressionRequirement
  - class: MultipleInputFeatureRequirement
  - class: InlineJavascriptRequirement
    expressionLib:
    - var get_root = function(basename) {
          return basename.split('.').slice(0,1).join('.');
      };


inputs:

  fastq_file_1:
    type: File
    doc: "Paired-end sequencing data 1 in FASTQ format (fastq, fq, bzip2, gzip, zip)"

  fastq_file_2:
    type: File
    doc: "Paired-end sequencing data 2 in FASTQ format (fastq, fq, bzip2, gzip, zip)"

  indices_folder:
    type: Directory
    doc: "Directory with the genome indices generated by Bowtie2"

  exclude_chromosome:
    type: string?
    default: "chrM chrY chrX"
    doc: "Case-sensitive space-separated chromosome list to be excluded"

  blacklisted_regions_bed:
    type: File
    doc: "Blacklisted genomic regions file in BED format"

  genome_size:
    type: string
    doc: "The length of the mappable genome (hs, mm, ce, dm or number, for example 2.7e9)"

  genome_fasta_file:
    type: File
    secondaryFiles:
    - .fai
    doc: "Reference genome sequence FASTA and FAI index files"

  threads:
    type: int?
    default: 4
    doc: "Number of threads for those steps that support multithreading"


outputs:

  fastqc_report_fastq_1:
    type: File
    outputSource: rename_fastqc_report_fastq_1/target_file

  trimgalore_report_fastq_1:
    type: File
    outputSource: trim_adapters/report_file

  fastqc_report_fastq_2:
    type: File
    outputSource: rename_fastqc_report_fastq_2/target_file

  trimgalore_report_fastq_2:
    type: File
    outputSource: trim_adapters/report_file_pair
  
  bowtie_alignment_report:
    type: File
    outputSource: align_reads/output_log

  aligned_reads:
    type: File
    outputSource: sort_and_index_after_filtering/bam_bai_pair

  bam_statistics_report:
    type: File
    outputSource: get_bam_statistics/log_file

  samtools_rmdup_report:
    type: File
    outputSource: remove_duplicates/rmdup_log

  bam_statistics_report_after_filtering:
    type: File
    outputSource: get_bam_statistics_after_filtering/log_file

  overall_collected_statistics:
    type: File
    outputSource: collect_statistics/collected_statistics

  macs2_peak_calling_report:
    type: File
    outputSource: call_peaks/macs_log

  merged_peaks_with_counts:
    type: File
    outputSource: count_tags/intersected_file

  merged_peaks_sequences:
    type: File
    outputSource: get_sequences/sequences_file


steps:


# -----------------------------------------------------------------------------------


  extract_fastq_1:
    run: ../../tools/extract-fastq.cwl
    in:
      compressed_file: fastq_file_1
    out: [fastq_file]

  run_fastqc_fastq_1:
    run: ../../tools/fastqc.cwl
    in:
      reads_file: extract_fastq_1/fastq_file
    out:
      - summary_file
      - html_file

  rename_fastqc_report_fastq_1:
    run: ../../tools/rename.cwl
    in:
      source_file: run_fastqc_fastq_1/html_file
      target_filename:
        source: fastq_file_1
        valueFrom: $(get_root(self.basename)+"_fastqc_report.html")
    out: [target_file]

  trigger_adapter_trimming_fastq_1:
    run: ../../tools/fastqc-results-trigger.cwl
    in:
      summary_file: run_fastqc_fastq_1/summary_file
    out: [trigger]


# -----------------------------------------------------------------------------------


  extract_fastq_2:
    run: ../../tools/extract-fastq.cwl
    in:
      compressed_file: fastq_file_2
    out: [fastq_file]

  run_fastqc_fastq_2:
    run: ../../tools/fastqc.cwl
    in:
      reads_file: extract_fastq_2/fastq_file
    out:
      - summary_file
      - html_file

  rename_fastqc_report_fastq_2:
    run: ../../tools/rename.cwl
    in:
      source_file: run_fastqc_fastq_2/html_file
      target_filename:
        source: fastq_file_2
        valueFrom: $(get_root(self.basename)+"_fastqc_report.html")
    out: [target_file]

  trigger_adapter_trimming_fastq_2:
    run: ../../tools/fastqc-results-trigger.cwl
    in:
      summary_file: run_fastqc_fastq_2/summary_file
    out: [trigger]


# -----------------------------------------------------------------------------------


  trim_adapters:
    run: ../../tools/trimgalore.cwl
    in:
      trigger:
        source: [trigger_adapter_trimming_fastq_1/trigger, trigger_adapter_trimming_fastq_2/trigger]
        valueFrom: $(self[0] || self[1])               # run trimgalore if at least one of input fastq files failed quality check
      input_file: extract_fastq_1/fastq_file
      input_file_pair: extract_fastq_2/fastq_file
      quality:
        default: 30      # Why do we need it if default should be 20
      dont_gzip:
        default: true    # should make it faster
      length:
        default: 30      # discard all reads shorter than 30 bp
      paired:
        default: true
    out:
      - trimmed_file
      - trimmed_file_pair
      - report_file
      - report_file_pair


# -----------------------------------------------------------------------------------


  rename_trimmed_fastq_1:
    run: ../../tools/rename.cwl
    in:
      source_file: trim_adapters/trimmed_file
      target_filename:
        source: fastq_file_1
        valueFrom: $(get_root(self.basename) + ".fastq")
    out: [target_file]

  rename_trimmed_fastq_2:
    run: ../../tools/rename.cwl
    in:
      source_file: trim_adapters/trimmed_file_pair
      target_filename:
        source: fastq_file_2
        valueFrom: $(get_root(self.basename) + ".fastq")
    out: [target_file]


# -----------------------------------------------------------------------------------


  align_reads:
    run: ../bowtie2/bowtie2.cwl
    in:
      filelist: rename_trimmed_fastq_1/target_file
      filelist_mates: rename_trimmed_fastq_2/target_file
      indices_folder: indices_folder
      end_to_end_very_sensitive:
        default: true
      maxins:
        default: 2000
      no_discordant:          # do we need it?
        default: true
      no_mixed:               # do we need it?
        default: true
      output_filename:
        source: [rename_trimmed_fastq_1/target_file, rename_trimmed_fastq_2/target_file]
        valueFrom: $(get_root(self[0].basename) + "_" + get_root(self[1].basename) + ".sam")
      threads: threads
    out:
      - output
      - output_log

  sort_and_index:
    run: ../../tools/samtools-sort-index.cwl
    in:
      sort_input: align_reads/output
      threads: threads
    out: [bam_bai_pair]

  get_bam_statistics:
    run: ../../tools/samtools-stats.cwl
    in:
      bambai_pair: sort_and_index/bam_bai_pair
      output_filename:
        source: sort_and_index_after_filtering/bam_bai_pair
        valueFrom: $(get_root(self.basename)+"_bam_statistics_report.txt")
    out:
      - log_file
      - average_length


# -----------------------------------------------------------------------------------


  filter_reads:
    run: ../../tools/samtools-filter.cwl
    in:
      bam_bai_pair: sort_and_index/bam_bai_pair
      exclude_chromosome: exclude_chromosome
      quality:
        default: 30                 # how do we define 30 (range is from 0 to 255)
      negative_flag:
        default: 4                  # correspond to -F 4 (read unmapped)
    out: [filtered_bam_bai_pair]
  
  remove_duplicates:
    run: ../../tools/samtools-rmdup.cwl
    in:
      bam_file: filter_reads/filtered_bam_bai_pair
    out:
    - rmdup_output
    - rmdup_log

  sort_and_index_after_filtering:
    run: ../../tools/samtools-sort-index.cwl
    in:
      sort_input: remove_duplicates/rmdup_output 
      threads: threads
    out: [bam_bai_pair]

  get_bam_statistics_after_filtering:
    run: ../../tools/samtools-stats.cwl
    in:
      bambai_pair: sort_and_index_after_filtering/bam_bai_pair
      output_filename:
        source: sort_and_index_after_filtering/bam_bai_pair
        valueFrom: $(get_root(self.basename)+"_bam_statistics_report_after_filtering.txt")
    out: [log_file]

  convert_bam_to_bed:
    run: ../../tools/bedtools-bamtobed.cwl
    in:
      bam_file: sort_and_index_after_filtering/bam_bai_pair   # do we need to split reads by N
    out: [bed_file]

  shift_reads:
    run: ../../tools/custom-bash.cwl
    in:
      input_file: convert_bam_to_bed/bed_file
      script:
        default: cat "$0" | awk 'BEGIN {OFS = "\t"}; {if ($6 == "+") print $1,$2+4,$3+4,$4,$5,$6; else print $1,$2-5,$3-5,$4,$5,$6}' > `basename $0`
    out: [output_file]

  remove_blacklisted:
    run: ../../tools/bedtools-intersect.cwl
    in:
      file_a: shift_reads/output_file
      file_b: blacklisted_regions_bed
      no_overlaps:
        default: true
    out: [intersected_file]


# -----------------------------------------------------------------------------------


  call_peaks:
    run: ../../tools/macs2-callpeak.cwl
    in:
      treatment_file: remove_blacklisted/intersected_file
      format_mode:
        default: "BED"
      genome_size: genome_size
      keep_dup:
        default: "all"
      nomodel:
        default: true
      shift:
        source: get_bam_statistics/average_length
        valueFrom: $(-Math.round(self/2))
      extsize: get_bam_statistics/average_length
    out:
      - narrow_peak_file
      - macs_log

  sort_peaks:
    run: ../../tools/linux-sort.cwl
    in:
      unsorted_file: call_peaks/narrow_peak_file
      key:
        default: ["1,1","2,2n"]
    out: [sorted_file]

  merge_peaks:
    run: ../../tools/bedtools-merge.cwl
    in:
      bed_file: sort_peaks/sorted_file
    out: [merged_bed_file]

  count_tags:
    run: ../../tools/bedtools-intersect.cwl
    in:
      file_a: merge_peaks/merged_bed_file
      file_b: remove_blacklisted/intersected_file
      count:
        default: true
    out: [intersected_file]

  get_sequences:
    run: ../../tools/bedtools-getfasta.cwl
    in:
      genome_fasta_file: genome_fasta_file
      intervals_file: merge_peaks/merged_bed_file
    out: [sequences_file]


  # -----------------------------------------------------------------------------------


  collect_statistics:
      run: get-stat-atacseq-pe.cwl
      in:
        trimgalore_report_fastq_1: trim_adapters/report_file
        trimgalore_report_fastq_2: trim_adapters/report_file_pair
        bam_statistics_report: get_bam_statistics/log_file
        bowtie_alignment_report: align_reads/output_log
        bam_statistics_report_after_filtering: get_bam_statistics_after_filtering/log_file
        reads_after_removal_blacklisted: remove_blacklisted/intersected_file
        peaks_called: call_peaks/narrow_peak_file
        peaks_merged: merge_peaks/merged_bed_file
        output_filename:
          source: align_reads/output
          valueFrom: $(get_root(self.basename)+"_collected_statistics_report.txt")
      out: [collected_statistics]
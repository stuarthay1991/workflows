cwlVersion: v1.0
class: CommandLineTool


requirements:
- class: ShellCommandRequirement
- class: InlineJavascriptRequirement
  expressionLib:
  - var get_output_filename = function() {
        if (inputs.output_filename) {
          return inputs.output_filename;
        }
        var root = inputs.bam_statistics_report.basename.split('.').slice(0,-1).join('.');
        var ext = "_collected_statistics_report.txt";
        return (root == "")?inputs.bam_statistics_report.basename+ext:root+ext;
    };


hints:
- class: DockerRequirement
  dockerPull: biowardrobe2/scidap:v0.0.3


inputs:

  script:
    type: string?
    default: |
      #!/usr/bin/env python
      import sys, re

      collected_results = []

      def get_value(l):
        return l.split(":")[1].strip().split()[0]

      collected_results.append(["#", "Adapter trimming statistics"])

      n = 0
      if (len(sys.argv) < 11):  # no trimming reports
        collected_results.append( [ "Skip adapter trimming for FASTQ1:", "True" ] )
        collected_results.append( [ "Skip adapter trimming for FASTQ2:", "True" ] )
        n = -2
      else:
        with open(sys.argv[1], 'r') as s:
          for l in s:
            if "Total reads processed" in l:
              collected_results.append( [ "Total reads processed (FASTQ1):", get_value(l) ] )
            if "Reads with adapters" in l:
              collected_results.append( [ "Reads with adapters (FASTQ1):",   get_value(l) ] )
            if "Reads written (passing filters)" in l:
              collected_results.append( [ "Reads passing filters (FASTQ1):", get_value(l) ] )

        with open(sys.argv[2], 'r') as s:
          for l in s:
            if "Total reads processed" in l:
              collected_results.append( [ "Total reads processed (FASTQ2):",    get_value(l) ] )
            if "Reads with adapters" in l:
              collected_results.append( [ "Reads with adapters (FASTQ2):",      get_value(l) ] )
            if "Reads written (passing filters)" in l:
              collected_results.append( ["Reads passing filters (FASTQ2):",     get_value(l) ] )
            if "Number of sequence pairs removed" in l:
              collected_results.append( ["Number of sequence pairs removed:", get_value(l) ] )
        
      collected_results.append(["#", "BAM statistics"])

      with open(sys.argv[3+n], 'r') as s:
        short_fragments, long_fragments = 0, 0
        for l in s:
          if "SN\traw total sequences:" in l:
            collected_results.append( [ "Raw total sequences:", get_value(l) ] )
          if "SN\t1st fragments:" in l:
            collected_results.append( [ "1st fragments:",       get_value(l) ] )
          if "SN\tlast fragments:" in l:
            collected_results.append( [ "Last fragments:",      get_value(l) ] )
          if "SN\treads mapped:" in l:
            collected_results.append( [ "Reads mapped:",        get_value(l) ] )
          if "SN\taverage length:" in l:
            collected_results.append( [ "Average length:",      get_value(l) ] )
          if "SN\tmaximum length:" in l:
            collected_results.append( [ "Maximum length:",      get_value(l) ] )
          if "SN\taverage quality:" in l:
            collected_results.append( [ "Average quality:",     get_value(l) ] )
          if "SN\tinsert size average:" in l:
            collected_results.append( [ "Insert size average:", get_value(l) ] )
          if "SN\tinsert size standard deviation:" in l:
            collected_results.append( [ "Insert size standard deviation", get_value(l) ] )
          if "IS" in l and not "grep" in l:
            fl = int(l.strip().split()[1])
            fc = int(l.strip().split()[2])
            if fl < 150:
              short_fragments = short_fragments + fc
            else:
              long_fragments = long_fragments + fc
        try:
          collected_results.append( [ "Insert size ratio (l<150 / l>=150)", str(float(short_fragments)/float(long_fragments)) ] )
        except:
          collected_results.append( [ "Insert size ratio (l<150 / l>=150)", "N/A" ] )


      with open(sys.argv[4+n], 'r') as s:
        for l in s:
          if "Uniquely mapped reads number" in l:
              collected_results.append( [ "Uniquely mapped reads number:", l.split("|")[1].strip() ] )
          if "Number of reads mapped to multiple loci" in l:
              collected_results.append( [ "Number of reads mapped to multiple loci:", l.split("|")[1].strip() ] )
          if "Number of reads mapped to too many loci" in l:
              collected_results.append( [ "Number of reads mapped to too many loci:", l.split("|")[1].strip() ] )

      with open(sys.argv[5+n], 'r') as s:
        for l in s:
          if "chrM" in l:
              collected_results.append( [ "Reads aligned to chrM:", l.split()[1].strip() ] )

      collected_results.append(["#", "BAM statistics after quality and duplicate filtering"])

      with open(sys.argv[6+n], 'r') as s:
        short_fragments, long_fragments = 0, 0
        for l in s:
          if "SN\traw total sequences:" in l:
            collected_results.append( [ "Raw total sequences:", get_value(l) ] )
          if "SN\t1st fragments:" in l:
            collected_results.append( [ "1st fragments:",       get_value(l) ] )
          if "SN\tlast fragments:" in l:
            collected_results.append( [ "Last fragments:",      get_value(l) ] )
          if "SN\treads mapped:" in l:
            collected_results.append( [ "Reads mapped:",        get_value(l) ] )
          if "SN\taverage length:" in l:
            collected_results.append( [ "Average length:",      get_value(l) ] )
          if "SN\tmaximum length:" in l:
            collected_results.append( [ "Maximum length:",      get_value(l) ] )
          if "SN\taverage quality:" in l:
            collected_results.append( [ "Average quality:",     get_value(l) ] )
          if "SN\tinsert size average:" in l:
            collected_results.append( [ "Insert size average:", get_value(l) ] )
          if "SN\tinsert size standard deviation:" in l:
            collected_results.append( [ "Insert size standard deviation:", get_value(l) ] )
          if "IS" in l and not "grep" in l:
            fl = int(l.strip().split()[1])
            fc = int(l.strip().split()[2])
            if fl < 150:
              short_fragments = short_fragments + fc
            else:
              long_fragments = long_fragments + fc
        try:
          collected_results.append( [ "Insert size ratio (l<150 / l>=150)", str(float(short_fragments)/float(long_fragments)) ] )
        except:
          collected_results.append( [ "Insert size ratio (l<150 / l>=150)", "N/A" ] )

      collected_results.append(["#", "Blacklisted regions filtering"])
      reads_after_blackisted_regions_removal = len(open(sys.argv[7+n]).readlines())
      collected_results.append( [ "Reads after blackisted regions removal:", str(reads_after_blackisted_regions_removal) ] )
      collected_results.append(["#", "Peak calling"])
      collected_results.append( [ "Number of peaks called:", str(len(open(sys.argv[8+n]).readlines())) ] )
      collected_results.append( [ "Number of peaks after merging:", str(len(open(sys.argv[9+n]).readlines())) ] )
      reads_under_the_merged_peaks = float(sum([int(l.strip().split()[3]) for l in open(sys.argv[10+n]).readlines()]))
      collected_results.append( [ "Fraction of Reads in Peaks (FRIP):",  str(reads_under_the_merged_peaks/reads_after_blackisted_regions_removal)] )

      with open(sys.argv[11+n], 'w') as fstream:
        for i in collected_results:
          fstream.write("\t".join(i)+"\n")
    inputBinding:
      position: 5

  trimgalore_report_fastq_1:
    type: File?
    inputBinding:
      position: 6

  trimgalore_report_fastq_2:
    type: File?
    inputBinding:
      position: 7

  bam_statistics_report:
    type: File
    inputBinding:
      position: 8

  star_alignment_report:
    type: File
    inputBinding:
      position: 9

  reads_per_chr_report:
    type: File
    inputBinding:
      position: 10

  bam_statistics_report_after_filtering:
    type: File
    inputBinding:
      position: 11

  reads_after_removal_blacklisted:
    type: File
    inputBinding:
      position: 12

  peaks_called:
    type: File
    inputBinding:
      position: 13

  peaks_merged:
    type: File
    inputBinding:
      position: 14

  merged_peaks_with_counts:
    type: File
    inputBinding:
      position: 15

  output_filename:
    type: string?
    inputBinding:
      position: 16
      valueFrom: $(get_output_filename())
    default: ""


outputs:

  collected_statistics:
    type: File
    outputBinding:
      glob: $(get_output_filename())


baseCommand: [python, '-c']
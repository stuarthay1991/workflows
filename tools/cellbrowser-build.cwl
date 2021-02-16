cwlVersion: v1.0
class: CommandLineTool


hints:
- class: DockerRequirement
  dockerPull: biowardrobe2/cellbrowser:v0.0.1


requirements:
- class: InlineJavascriptRequirement
- class: InitialWorkDirRequirement
  listing:
  - entryname: cellbrowser.conf
    entry: |
      name = "cellbrowser"
      priority = 10
      tags = ["smartseq2"]
      shortLabel="CellBrowser"
      exprMatrix="expr_matrix.tsv"
      geneIdType="auto"
      meta="metadata.tsv"
      enumFields = ["c1_cell_id"]
      coords=[
        {
          "file":"coordinates.tsv", 
          "flipY" : False,
          "shortLabel":"Clustering"
        }
      ]
      clusterField="cluster"
      labelField="label"
  - entryname: desc.conf
    entry: |
      title = "CellBrowser"
      abstract = ""
      methods = ""
      biorxiv_url = ""
      custom = {"sample barcode": ""}


inputs:

  bash_script:
    type: string?
    default: |
      #!/bin/bash
      cp $0 expr_matrix.tsv
      echo -e "barcode\tcluster\tlabel" > metadata.tsv
      cat $1 >> metadata.tsv
      cp $2 coordinates.tsv
      cbBuild -o html_data
    inputBinding:
      position: 5
    doc: |
      Bash script to run cbBuild command

  expression_matrix_file:
    type: File
    inputBinding:
      position: 6
    doc: |
      Expression matrix: one row per gene and one column per cell, ideally gzipped.
      The first column must be the gene identifier or gene symbol, or ideally
      geneId|symbol. Ensembl/GENCODE gene identifiers starting with ENSG and ENSMUSG
      will be translated automatically to symbols. The other columns are expression
      values as numbers, one per cell. The number type will be auto-detected (float
      or int). The first line of the file must be a header that includes the cell
      identifiers.

  annotation_metadata_file:
    type: File
    inputBinding:
      position: 7
    doc: |
      Cell annotation metadata table, one row per cell. No need to gzip this relatively
      small file. The first column is the name of the cell and it has to match the name
      in the expression matrix. There should be at least two columns: one with the name
      of the cell and one with the name of the cluster. To speed up processing of both
      your expression matrix and metadata file, these files should describe the same
      numbers of cells and be in the same order. This allows cbBuild process these files
      without needing to trim the matrix and reorder the metadata file. The metadata file
      also must have a header line.

  coordinates_file:
    type: File
    inputBinding:
      position: 8
    doc: |
      Cell coordinates, often t-SNE or UMAP coordinates. This file always has three columns,
      (cellName, x, y). The cellName must be the same as in the expression matrix and cell
      annotation metadata file. If you have run multiple dimensionality reduction algorithms,
      you can specify multiple coordinate files in this format. The number rows in these
      coordinates doesn’t need to match that of your expression matrix or metadata files,
      allowing you to specify only a subset of the cells. In this way, you can use a single
      dimensionality reduction algorithm, but include multiple subsets and view of the cells,
      e.g. one coordinates file per tissue. Note, if R has changed your cell identifiers (e.g.
      by adding dots), you may be able to fix them by running cbTool metaCat.


outputs:

  html_data:
    type: Directory
    outputBinding: 
      glob: "html_data"

  stdout_log:
    type: stdout

  stderr_log:
    type: stderr


baseCommand: ["bash", "-c"]

stdout: cbbuild_stdout.log
stderr: cbbuild_stderr.log


$namespaces:
  s: http://schema.org/

$schemas:
- https://github.com/schemaorg/schemaorg/raw/main/data/releases/11.01/schemaorg-current-http.rdf

s:name: "cellbrowser-build"
s:downloadUrl: https://raw.githubusercontent.com/Barski-lab/workflows/master/tools/cellbrowser-build.cwl
s:codeRepository: https://github.com/Barski-lab/workflows
s:license: http://www.apache.org/licenses/LICENSE-2.0

s:isPartOf:
  class: s:CreativeWork
  s:name: Common Workflow Language
  s:url: http://commonwl.org/

s:creator:
- class: s:Organization
  s:legalName: "Cincinnati Children's Hospital Medical Center"
  s:location:
  - class: s:PostalAddress
    s:addressCountry: "USA"
    s:addressLocality: "Cincinnati"
    s:addressRegion: "OH"
    s:postalCode: "45229"
    s:streetAddress: "3333 Burnet Ave"
    s:telephone: "+1(513)636-4200"
  s:logo: "https://www.cincinnatichildrens.org/-/media/cincinnati%20childrens/global%20shared/childrens-logo-new.png"
  s:department:
  - class: s:Organization
    s:legalName: "Allergy and Immunology"
    s:department:
    - class: s:Organization
      s:legalName: "Barski Research Lab"
      s:member:
      - class: s:Person
        s:name: Michael Kotliar
        s:email: mailto:misha.kotliar@gmail.com
        s:sameAs:
        - id: http://orcid.org/0000-0002-6486-3898


doc: |
  Converts AltAnalyze outputs into the data structure supported by UCSC CellBrowser


s:about: |
  Usage: cbBuild [options] -i cellbrowser.conf -o outputDir - add a dataset to the single cell viewer directory

      If you have previously built into the same output directory with the same dataset and the
      expression matrix has not changed its filesize, this will be detected and the expression
      matrix will not be copied again. This means that an update of a few meta data attributes
      is quite quick.

  Options:
    -h, --help            show this help message and exit
    --init                copy sample cellbrowser.conf and desc.conf to current
                          directory
    -d, --debug           show debug messages
    -i INCONF, --inConf=INCONF
                          a cellbrowser.conf file that specifies labels and all
                          input files, default is ./cellbrowser.conf, can be
                          specified multiple times
    -o OUTDIR, --outDir=OUTDIR
                          output directory, default can be set through the env.
                          variable CBOUT or ~/.cellbrowser.conf, current value:
                          none
    -p PORT, --port=PORT  if build is successful, start an http server on this
                          port and serve the result via http://localhost:port
    -r, --recursive       run in all subdirectories of the current directory.
                          Useful when rebuilding a full hierarchy.
    --redo=REDO           do not use cached old data. Can be: 'meta' or 'matrix'
                          (matrix includes meta).
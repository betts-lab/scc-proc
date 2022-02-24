# scc-proc
Upstream processing for single cell ADT-based sequencing

## Necessary files

### 1) `config.yaml`
> Example configuration is shown below.

- This file must be at the same level as the `Snakefile`.
- Multiple samples can be added to the config assuming they follow the same antibody mixture and bead setup.
- All fastq files must be in the fastq_dir path
    - Specific filenames are provided in the `samples` attribute of the yaml file.

```
dirs:
  fastq_dir: fastq/
files:
  abs_csv: abs.csv
  whitelist: whitelist.txt
general_settings:
    threads: 4
samples:
  - name: ND542_PBMC
    R1: "ND542_PBMC_S1_R1_001.fastq.gz"
    R2: "ND542_PBMC_S1_R2_001.fastq.gz"
  - name: Sample_2
    R1: "Sample_2_S2_R1_001.fastq.gz"
```

### 2) fastq files
> Refer to config above

### 3) Antibody file
> Comma separted file with barcodes and descriptions. Example below:

```
CD40,CTCAGATGGAGTATG
CD44,AATCCTTCCGAATGT
CD48,CTACGACGTAGAAGA
CD21,AACCTAGTAGTTCGG
```

### 4) Allowlist cell barcode file
> Allowlist cell barcode per line. Example below:

```
GTCTGCTATGTCTA
GATGATGCATAGAA
```

## Setup
1. Create conda env
```
conda create --name <env> --file environment_osx.txt
```

2. Run Snakemake
```
snakemake --cores 4
```
The overall process will look like this:

![DAG image](dag.png)

3. Downstream analysis of your own choosing. The count matrix and corresponding row/col info will be found in `{sample_name}_{sample_index}_output_count/`

## Credits
- [Conda](https://docs.conda.io/en/latest/)
- [Snakemake](https://snakemake.readthedocs.io/en/stable/)
- [Kallisto](https://pachterlab.github.io/kallisto/)
- [Kallisto KITE featureMap.py](https://github.com/pachterlab/kite/tree/master/featuremap)
- [Bustools](https://github.com/BUStools/bustools)
- [kallisto | bustools KITE protocol](https://bustools.github.io/BUS_notebooks_R/10xv3.html)
    - I made my Snakemake pipeline heavily based on their pipeline.
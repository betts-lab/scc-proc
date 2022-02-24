import yaml
import os
import re

config_path = 'config.yaml'

with open(config_path, 'r') as infile:
    raw_config = yaml.safe_load(infile.read())

    fastq_dir = raw_config["dirs"]["fastq_dir"]
    smpls = list(map(lambda x: x['name'], raw_config["samples"]))

    smpls_with_index = [[x, i] for i,x in enumerate(smpls)]


configfile: "config.yaml"

tmp_dir = "tmp/"
scripts_dir = "scripts/"

rule all:
    input:
        expand(f"{{smpl[0]}}_{{smpl[1]}}_output_count/output.mtx",
            smpl = smpls_with_index)

# python script from https://github.com/pachterlab/kite/tree/master/featuremap
rule build_feature_barcodes:
    input:
        config["files"]["abs_csv"]
    output:
        t2g = tmp_dir + "abs.t2g",
        fa = tmp_dir + "abs.fa"
    params:
        feat_map = scripts_dir + "featuremap.py"
    shell:
        "python {params.feat_map} {input} --t2g {output.t2g} --fa {output.fa}"

rule make_index:
    input:
        rules.build_feature_barcodes.output.fa
    output:
        tmp_dir + "abs.idx"
    shell:
        "kallisto index -i {output} -k 15 {input}"

rule make_bus:
    input:
        fastqs = lambda wildcards: map(lambda x : fastq_dir + x, [config["samples"][int(wildcards.i)]["R1"], config["samples"][int(wildcards.i)]["R2"]]),
        idx = rules.make_index.output
    output:
        bus = "{smpl}_{i}_output_bus/output.bus"
    params:
        out_dir = "{smpl}_{i}_output_bus/",
        threads = config["general_settings"]["threads"]
    shell:
        "kallisto bus -x 0,0,29:0,29,37:1,0,0 -i {input.idx} -t {params.threads} -o {params.out_dir} {input.fastqs}"

rule correct_cbc:
    input:
        rules.make_bus.output.bus
    output:
        rules.make_bus.params.out_dir + "output.corrected.bus"
    params:
        allowlist = config["files"]["allowlist"]
    shell:
        "bustools correct -w {params.allowlist} -o {output} {input} "

rule sort_bus:
    input:
        rules.correct_cbc.output
    output:
        rules.make_bus.params.out_dir + "output.corrected.sorted.bus"
    params:
        threads = config["general_settings"]["threads"]
    shell:
        "bustools sort -t {params.threads} -o {output} {input}"

rule make_count_matrix:
    input:
        rules.sort_bus.output
    output:
        "{smpl}_{i}_output_count/output.mtx",
    params:
        count_output = "{smpl}_{i}_output_count/",
        t2g = rules.build_feature_barcodes.output.t2g,
        ec = rules.make_bus.params.out_dir + "matrix.ec",
        txt = rules.make_bus.params.out_dir + "transcripts.txt"
    shell:
        "bustools count -o {params.count_output} --genecounts -g {params.t2g} -e {params.ec} -t {params.txt} {input}"
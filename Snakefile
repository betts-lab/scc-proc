import yaml
import os
import re
import sys

config_path = 'config.yaml'
configfile: config_path

with open(config_path, 'r') as infile:
  raw_config = yaml.safe_load(infile.read())

  fastqDir = os.path.normpath(raw_config["dirs"]["fastq_dir"])
  smplsNames = raw_config["samples"]

  smplDict = {}
  for s in raw_config["samples"]:
    smplDict[s["name"]] = s
  

  modalities = raw_config["general_settings"]["modes"]
  outDir = os.path.normpath(raw_config["dirs"]["out_dir"])
  tmpDir = outDir + "/" + "kallisto_tmp"
  
  if not os.path.exists(outDir):
    os.mkdir(outDir)
  
  if not os.path.exists(tmpDir):
    os.mkdir(tmpDir)
  
#   for m in modalities:
#     for s in smplsNames:
#       finalDir = "{}/{}_{}_output_count".format(outDir, s, m)
#       if not os.path.exists(finalDir):
#         os.mkdir(finalDir)
# 
  scripts_dir = os.path.realpath(workflow.basedir) + "/scripts"

rule all:
  input:
    expand(f"{{outputDir}}/{{smpl}}_{{modality}}_output_count/output.mtx",
      outputDir = outDir,
      smpl = smplDict.keys(),
      modality = modalities)

def get_modalities_catalogs(wildcards):
  modalityKey = wildcards.modality + "_catalog"
  return(raw_config["files"][modalityKey])

# python script from https://github.com/pachterlab/kite/tree/master/featuremap
rule build_preIndex:
  input:
    get_modalities_catalogs
  output:
    t2g = tmpDir + "/{modality}.t2g",
    fa = tmpDir + "/{modality}.fa"
  params:
    feat_map = scripts_dir + "/featuremap.py"
  shell:
    "python {params.feat_map} {input} --t2g {output.t2g} --fa {output.fa}"


rule make_index:
  input:
    rules.build_preIndex.output.fa
  output:
    tmpDir + "/{modality}.idx"
  params:
    kmer = raw_config["general_settings"]["tag"][2] - raw_config["general_settings"]["tag"][1]
  shell:
    "kallisto index -i {output} -k {params.kmer} {input}"


def get_sample_fastqs(wildcards):
  modalityKey = wildcards.modality + "_" + "fastqs"
  inputs = {
    "fastqs": [fastqDir + "/" + x for x in smplDict[wildcards.smpl][modalityKey]],
    "idx": tmpDir + "/" + wildcards.modality + ".idx"
  }
  
  return(inputs)

def convert_list_to_bus_params(l):
  return(",".join([str(x) for x in l]))

rule make_bus:
  input:
    unpack(get_sample_fastqs)
  output:
    bus = outDir + "/{smpl}_{modality}_output_bus/output.bus"
  params:
    cbc = convert_list_to_bus_params(raw_config["general_settings"]["cbc"]),
    umi = convert_list_to_bus_params(raw_config["general_settings"]["umi"]),
    tag = convert_list_to_bus_params(raw_config["general_settings"]["tag"]),
    out_dir = outDir + "/{smpl}_{modality}_output_bus/",
    threads = config["general_settings"]["threads"]
  shell:
    "kallisto bus -x {params.cbc}:{params.umi}:{params.tag} -i {input.idx} -t {params.threads} -o {params.out_dir} {input.fastqs}"

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
    outDir + "/{smpl}_{modality}_output_count/output.mtx",
  params:
    count_output = outDir + "/{smpl}_{modality}_output_count/",
    t2g = rules.build_preIndex.output.t2g,
    ec = rules.make_bus.params.out_dir + "matrix.ec",
    txt = rules.make_bus.params.out_dir + "transcripts.txt"
  shell:
    "bustools count -o {params.count_output} --genecounts -g {params.t2g} -e {params.ec} -t {params.txt} {input}"

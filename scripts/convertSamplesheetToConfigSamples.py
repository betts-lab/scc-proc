import argparse
import csv
import os.path
import re


def generateSample(s_adt = None, s_hto = None):
  if s_adt != None:
    adt_sn = s_adt["sample"]
    adt_n = s_adt["sample_n"]
    
    s = adt_sn.replace("_ADT", "") 
    s = s.rstrip("_")


  if s_hto != None:
    hto_sn= s_hto["sample"]
    hto_n = s_hto["sample_n"]
  
    s = hto_sn.replace("_HTO", "")
    s = s.rstrip("_")


  if s_adt != None and s_hto != None:
    sample = f'''\
      - name: {s}
        adt_fastqs: ["{adt_sn}_S{adt_n}_R1_001.fastq.gz", "{adt_sn}_S{adt_n}_R3_001.fastq.gz"]
        hto_fastqs: ["{hto_sn}_S{hto_n}_R1_001.fastq.gz", "{hto_sn}_S{hto_n}_R3_001.fastq.gz"]'''
  
  elif s_adt != None:
    sample = f'''\
      - name: {s}
        adt_fastqs: ["{adt_sn}_S{adt_n}_R1_001.fastq.gz", "{adt_sn}_S{adt_n}_R3_001.fastq.gz"]'''
  
  elif s_hto != None:
    sample = f'''\
      - name: {s}
        hto_fastqs: ["{hto_sn}_S{hto_n}_R1_001.fastq.gz", "{hto_sn}_S{hto_n}_R3_001.fastq.gz"]'''
  
  return(sample)

def main(args):
  samples = []
  skip = False
  foundSamples = False

  with open(args.samplesheet, "r") as csvfile:
    reader = csv.reader(csvfile, delimiter = ",")

    for row in reader:
      if row[0] == "[Data]":
        skip = True
        foundSamples = True
        continue

      elif skip:
        skip = False
        continue

      if foundSamples:
        samples.append(row[0])


  samples = [{"sample": s, "sample_n": i + 1} for i,s in enumerate(samples)]
  samples = sorted(samples, key = lambda x: x["sample"])

  jumper = 2 if args.adt and args.hto else 1
  for i in range(0, len(samples), jumper):
    if args.adt and args.hto:
      print(generateSample(s_adt = samples[i], s_hto = samples[i+1]))
    elif args.adt:
      print(generateSample(s_adt = samples[i]))
    elif args.hto:
      print(generateSample(s_hto = samples[i]))
      

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description = "Parser to convert samplesheet to config.yaml samples format")
  parser.add_argument("-s", "--samplesheet", required = True, help = "Samplesheet csv file path")
  parser.add_argument("--adt", required = False, action = "store_true", help = "adt mode")
  parser.add_argument("--hto", required = False, action = "store_true", help = "hto mode")

  args = parser.parse_args()

  if not os.path.exists(args.samplesheet):
    raise Exception("Samplesheet not found")

  if not args.adt and not args.hto:
    raise Exception("Need to set either adt or hto mode")

main(args)

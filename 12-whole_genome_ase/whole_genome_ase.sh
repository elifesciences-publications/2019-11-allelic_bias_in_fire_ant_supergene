#!/bin/sh
module load bcftools/1.8
module load samtools/1.9
#The ASE analysis performed on the supergene is repeated here on the whole genome. The differences with the original
#analyisis (other than using the whole genome now) is that we will not focus on fixed differences only, and this
#analysis will be performed for South American populations only. The aim is to detect whether we have enough power
#to detect ASE differences between body parts at all.

#Sort gng vcf. The name of the output sorted vcf is just to make it compatible with downstream scripts
bcftools sort -o input/subset.vcf input/gng_vcf_sa.vcf
#-------- GENERATE ALTERNATIVE REFERENCE -------------------------
sh alternative_reference.sh
#Get the new alternative reference and move it to input for the next step
gzip -c tmp/Si_gnG_littleb.fna > input/reference.fna.gz

#------- ALIGN THE READS TO ALTERNATIVE REFERENCE ---------------------
#Generate a splice junction file for the alternative reference
sh star_alignment_all_samples_south_america.sh
#Change name of the output bam directory
mv tmp/bam_files tmp/bam_all
#Change name of the referecne directory
mv tmp/star_reference_south_america tmp/star_reference
#Link the splice junction file to input
ln -sr tmp/bam_all/all_samples_south_americaSJ.out.tab input
#Generate a text file with the sample names
ls input/ar_trimmed_reads/*gz | cut -d "/"  -f3 | cut -d "R" -f1 | sort -u > tmp/samples.txt

mkdir tmp/bam_files
#Run actual alignment in an array job
qsub star_alignment_south_america.array.sh
#Add inputs for the next step (bam merging + WASP removal of duplicates)
ln -sr ../../results/2018-12-03-B_align_south_american_rna_to_BigB_gnG/results/ input/bigB_bam
ln -sr tmp/bam_files/ input/littleb_bam

#Run the script for creating reference bias free bam files
sh wasp_script.sh

#Get the results of the reference bias free bam files
ln -sr tmp/free_bias_bam/with_rg input/wasp_bam
#Generate a file with the path to all neutral bam files for North America
ls input/wasp_bam/*bam > path_to_bam.txt

#Generate a file with only the smaple ids
cat path_to_bam.txt | cut -d '/' -f 3 | cut -d '.' -f 1 > samples.ids
#Change name of the reference
mv tmp/Si_gnG.fa tmp/Si_gnG.fna

#GATK needs both an index and a dict file to run:
samtools faidx tmp/Si_gnG.fna
java -jar picard CreateSequenceDictionary REFERENCE=tmp/Si_gnG.fna OUTPUT=tmp/Si_gnG.fna.dict

#GATK needs a sorted vcf to run
java -jar picard SortVcf \
      I=input/subset.vcf \
      O=tmp/sorted_subset.vcf

#Run GATK to get ASE counts
qsub script_gatk_neutral_ref_south_america.array.sh

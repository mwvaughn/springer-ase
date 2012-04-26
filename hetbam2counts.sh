#!/bin/bash

# For each BAM file representing alignment of
# RNAseq reads from a hybrid to a reference
# genome
# hybridbam2counts.sh -i b73_tophat/accepted_hits.bam -v "HapMapv2_MO17.vcf:MO17_RNASeq_notHapMapV2.vcf" -1 "B73" -2 "MO17"

usage()
{
cat << EOF
usage: $0 options

Generates a tab-delimited read count file from heterozygote 
RNAseq alignments. Input is suitable for further use in
packages such as edgeR and DEGseq.

OPTIONS:
	-h	Show this message
	-i	BAM file containing heterozygote RNAseq alignments 
	-v	Colon-delimited list of VCF files describing variants
	-g	FASTA file for genome
	-a	GFF3 annotation file for genome
	-q	Minimum PHRED-scaled mapping quality for reads
		[default: 20]
	-t	GFF type to be mapped against
		[default: mRNA]
	-r	Regex for defining gene or locus names
		[default: maize-specific]
	-1	Short name for Reference parent (ex B73)
	-2	Short name for Non-reference parent (ex MO17)
	-o	Name of the output text file containing count data
		[default: final_ase_counts.txt]
	
Please note that the chromosome names and lengths for the BAM, VCF, 
and annotation files must be identical.
	
EOF
}

# PATH extension
# BEDtools
export PATH=/usr/local3/bin/BEDTools-Version-2.15.0/bin:${PATH}
# SAMTools
export PATH=/usr/local3/bin/samtools-0.1.16:${PATH}
# This script
export PATH=/usr/local3/bin/ase-1.00:${PATH}

BAMFILE=
VCFS=
ANNO=
GENOME=

MINMAPQUAL=

ANNO_MODE="BED"
GFFTYPE="exon"
#LOCUS_REGEX='GRMZM[0-9]+G[0-9]+_T[0-9]+|[AE][A-Z][0-9]+\.[0-9]+_FGT[0-9]+'
LOCUS_REGEX='GRMZM[0-9]+G[0-9]+|[AE][A-Z][0-9]+\.[0-9]+_FG[0-9]+'

REFNAME="Ref"
ALTNAME="Alt"

OUTPUT="final_ase_counts.txt"

while getopts “?hg:a:i:v:q:t:r:o:1:2:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         i)
             BAMFILE=$OPTARG
             ;;
         v)
             VCFS=$OPTARG
             ;;             
         g)
             GENOME=$OPTARG
             ;;
         a)
             ANNO=$OPTARG
             ANNO=${ANNO/gtf/gff}
             ;;
         q)
             MINMAPQUAL=$OPTARG
             ;;
         t)
             GFFTYPE=$OPTARG
             ;;
         r)
             LOCUS_REGEX="$OPTARG"
             ;;
         1)
             REFNAME=$OPTARG
             ;;
         2)
             ALTNAME=$OPTARG
             ;;             
         o)
             OUTPUT=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

# Filter input BAM on mapping quality
# This basically removes non-unique matches and other cruft
# May be a better way to do this but will do for now
#
if [ -n "$MINMAPQUAL" ]
then
echo "Filtering ${BAMFILE} to minimum mapping quality"
samtools view -bq ${MINMAPQUAL} ${BAMFILE} > filtered.bam
else
ln -s ${BAMFILE} filtered.bam
fi

echo "Summarizing alignment index stats"
samtools index filtered.bam
samtools flagstat filtered.bam > bam-flagstat.txt
samtools idxstats filtered.bam > bam-idxstats.txt

# Concatenate VCFs and strip headers
echo "Consolidating VCF files"
VCFLIST=${VCFS/:/ }
cat ${VCFLIST} | egrep -v "#" > master1.vcf

SUBSET=

if [ $ANNO_MODE == "GFF" ]
then
	# Filter annotation down to one feature type
	## May need to make this configurable in future
	SUBSET="subset.gff"
	# Filter annotation down to one feature type
	## May need to make this configurable in future
	echo "Extracting features from ${ANNO}"
	gfffilter.pl '$feature eq "mRNA"' ${ANNO} > $SUBSET
	# Creating gene manifest
	# regex is hard-coded now, but should be $LOCUS_REGEX
	echo "Creating gene manifest from ${ANNO}"
	cut -f 9 $SUBSET | egrep -o -e "${LOCUS_REGEX}" | sort | uniq > mrna.manifest
else
	SUBSET="subset.bed"
	cp $ANNO $SUBSET
	cut -f 4 $SUBSET | egrep -o -e "${LOCUS_REGEX}" | sort | uniq > mrna.manifest
fi

# Prune master1.vcf file to SNPs in mrna.gff
echo "Filtering variants to overlap ${ANNO}"
intersectBed -b $SUBSET -a master1.vcf -u > exon_snps.vcf

# Per-gene SNP counts
intersectBed -a $SUBSET -b exon_snps.vcf -c > perexon_snp_counts.bed
summarize_bed.pl perexon_snp_counts.bed "${LOCUS_REGEX}" mrna.manifest > pergene_snp_counts.txt

# Generate mpileup for filtered.bam at sites in exon_snps.vcf
echo "Generating mpileup at filtered variant sites"
#
if [ ! -e filtered.bam.mpileup ]
then
	samtools mpileup -BAQ0 -f ${GENOME} -d10000000 -l exon_snps.vcf filtered.bam > filtered.bam.mpileup
fi

# Generate rough BED files from mpileup file
echo "Converting mpileup to BED files"
mpileup2beds.pl exon_snps.vcf filtered.bam.mpileup

if [ $ANNO_MODE == "GFF" ]
then
	# Generate annotated BED files from mrna.gff
	echo "Annotating BED files with gene names"
	intersectBed -a $SUBSET -b filtered.bam.mpileup.ref.bed -wa -wb -bed | cut -f 1,4,5,9,13 > reference_counts.bed
	intersectBed -a $SUBSET -b filtered.bam.mpileup.alt.bed -wa -wb -bed | cut -f 1,4,5,9,13 > alternate_counts.bed
else
	# Generate annotated BED files from mrna.gff
	echo "Annotating BED files with gene names"
	intersectBed -a $SUBSET -b filtered.bam.mpileup.ref.bed -wa -wb -bed | cut -f 1,2,3,4,8 > reference_counts.bed
	intersectBed -a $SUBSET -b filtered.bam.mpileup.alt.bed -wa -wb -bed | cut -f 1,2,3,4,8 > alternate_counts.bed
fi

# Summarize counts by feature
# summarize_bed.pl defaults to extracting maize locus names
# but can accept a regex for your own gene names
#
echo "Collapsing per-exon counts into per-locus counts"
summarize_bed.pl reference_counts.bed "${LOCUS_REGEX}" > reference_counts.bed.txt
summarize_bed.pl alternate_counts.bed "${LOCUS_REGEX}" > alternate_counts.bed.txt

# Join into single file with columns
# GENE REF ALT
#
echo "Merging files"
join_wrapper.sh -j All -d tab -1 reference_counts.bed.txt -a 1 -2 alternate_counts.bed.txt -b 1 -o data.tab

echo -n -e "Gene\t${REFNAME}\t${ALTNAME}\n" > header.tab
cat header.tab data.tab > ${OUTPUT}

# Clean up
echo "Cleaning up"
rm data.tab header.tab $SUBSET filtered.bam.mpileup.* mrna.manifest master1.vcf perexon_snp_counts.bed
rm filtered.bam filtered.bam.bai 

exit 0

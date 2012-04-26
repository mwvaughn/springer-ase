#!/bin/env perl

# accepted_hits.bam -> mpileup at just the VCF sites
# mpileup2basecount.pl targets.vcf mpileup-file
## emits reference and alt bed files named a

use strict;
use warnings;

print STDERR "mpileup2beds.pl ";
print STDERR join(" ", @ARGV), "\n";

# Read in VCF containing reference and alternate base
my %snps;

open (VCF, $ARGV[0]) or die;
my $vcf = 0;
while (my $l = <VCF>) {
	
	unless ($l =~ /^#/) {
	
		chomp($l);
		$vcf++;
		my @f = split(/\t/, $l);
		my $seqid = uc($f[0]);
		my $start = $f[1];
		my $end = $f[1];

		my $refbase = $f[3];
		my $altbase = $f[4];
		
		$snps{"$seqid.$start"}->{'reference'} = $refbase;
		#print STDERR $snps{"$seqid.$start"}->{'reference'}, "\t";
		$snps{"$seqid.$start"}->{'alternate'} = $altbase;
		#print STDERR $snps{"$seqid.$start"}->{'alternate'}, "\n";
	
	}

}
print STDERR "$vcf variant sites loaded\n";
close VCF;

open (MPILEUP, $ARGV[1]) or die;
open (BEDREF, ">$ARGV[1].ref.bed") or die;
open (BEDALT, ">$ARGV[1].alt.bed") or die;

while (my $l = <MPILEUP>) {
	
	chomp($l);
	my @f = split(/\t/, $l);
	my $seqid = uc($f[0]);
	my $start = $f[1];
	my $bases = uc($f[4]);
	
	my $refbase = $snps{"$seqid.$start"}->{'reference'};
	my $altbase = $snps{"$seqid.$start"}->{'alternate'};
	
	my $refcount = 0;
	my $altcount = 0;
	
	my @chars = split(//, $bases);
	for (@chars) {
		
		if (($_ eq ".") or ($_ eq ",")) {
			$refcount++;
		} elsif ($_ eq $altbase) {
			$altcount++;
		}
	}
	
	#print STDERR "$seqid\t$start\t$refbase\t$altbase\t$refcount\t$altcount\n";
	print BEDREF $seqid, "\t", $start, "\t", $start, "\t", "", "\t", $refcount, "\n";
	print BEDALT $seqid, "\t", $start, "\t", $start, "\t", "", "\t", $altcount, "\n";

}

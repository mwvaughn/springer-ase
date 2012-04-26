#!/bin/env perl

open (BED, $ARGV[0]);
# Default to search for maize gene loci
my $regex = $ARGV[1] || "GRMZM[0-9]+G[0-9]+|[AE][A-Z][0-9]+\.[0-9]+_FG[0-9]+";
my $manifest = $ARGV[2] || "mrna.manifest";

print STDERR "summarize_bed.pl ";
print STDERR join(" ", @ARGV), "\n";

my %names_sums;

# Read in the optional manifest file
# Initialize the list of genes with zeros
#
# This ensures that the summary files all contain the same
# complement of genes, regardless of coverage and SNP density

if (-e $manifest) {
	open (MANIFEST, $manifest);
	while (my $g = <MANIFEST>) {
		chomp($g);
		my @gg = split(/\s+/, $g);
		$names_sums{$gg[0]} = 0;
	}
	close MANIFEST;
}

while (my $r = <BED>) {

	unless ($r =~ /^#|^\s+/) {
	
		chomp($r);
		my @f = split(/\t/, $r);
		my $name = $f[3];

		if ($name =~ /($regex)/) {
			$name = $1;
			#print STDERR $name, "\n";
		
			if (defined($names_sums{$name})) {
				$names_sums{$name} = $names_sums{$name} + $f[4];
			} else {
				$names_sums{$name} = $f[4]
			}
		
		}
		
	
	}

}

for my $k (sort keys %names_sums) {
	print $k, "\t", $names_sums{$k}, "\n";
}
#!/usr/bin/env perl

use strict;
use warnings;
use FindBin '$Bin';
use lib $Bin;
use MyGetopt;
use System qw/sys/;
use File::Basename;

my @domains = qw/archaea bacteria fungi invertebrate plant protozoa vertebrate_mammalian vertebrate_other viral/;

my $kmer_size = 21;
my $sketch_size = 1000;

my ($opt, $usage) = MyGetopt::describe_options(
        basename($0)." <long-options> DOMAIN",
        ["verbose", "Be verbose", {default=>0}],
        ["pretend", "Pretend system calls, only"],
        ["force", "Force system calls, even if file exists"],
        ["ask", "Ask before executing command", { default=>0}]
);

if (@ARGV == 0) { print $usage; exit 0; }

$System::pretend = $opt->pretend;
$System::verbose = $opt->verbose;
$System::force = $opt->force;
$System::ask = $opt->ask;

my $sketch_dir = "sketches-k${kmer_size}s${sketch_size}";
my $genomes_dir = "genomes";
mkdir $sketch_dir unless -d $sketch_dir; 
mkdir $genomes_dir unless -d $genomes_dir; 
foreach my $domain (@domains) {
    my $domain_dir = "$sketch_dir/$domain";
    my $genome_domain_dir = "$genomes_dir/$domain";
    mkdir $domain_dir unless -d $domain_dir;
    mkdir $genome_domain_dir unless -d $genome_domain_dir;
    my $assembly_summary_f = sys("curl ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/$domain/assembly_summary.txt",
        { output => "$domain_dir/assembly_summary.txt" });
    open (my $F, "<", $assembly_summary_f) or die "$!";
    my $line = <$F>;
    $line = <$F>;
    if (!$line =~ /^# assembly_accession/) {
        die "Expecting column headers in second line of file - aborting";
    }
    $line =~ s/^# //;
    my $i = 0;
    my %header = map { $_ => $i++ } split (/\t/, $line);;
    while ($line = <$F>) {
        next if $line =~ /^#/;
        my @dat = split(/\t/, $line);
        my $assembly_accession = $dat[$header{assembly_accession}];
        my $taxid = $dat[$header{taxid}];
        my $organism_name = $dat[$header{organism_name}];
        $organism_name =~ s/'/"/g;
        my $assembly_level = $dat[$header{assembly_level}];
        my $asm_name = $dat[$header{asm_name}];
        my $ftp_path = $dat[$header{ftp_path}];

        $assembly_level =~ s/ //g;
        $asm_name =~ s/[^A-Za-z0-9.\-\(\)]/_/g;
        #$asm_name =~ s/__/_/g;
        my $url = "$ftp_path/${assembly_accession}_${asm_name}_genomic.fna.gz";
        (my $organism_name1 = $organism_name) =~ s/[^A-Za-z0-9.\-]/_/g;
        my $genome_result_dir = "$genome_domain_dir/$assembly_level";
        mkdir $genome_result_dir unless -d $genome_result_dir;
        my $result_basename = "$assembly_accession-taxid$taxid-$organism_name1";
        my $fna_f = "$genome_result_dir/${result_basename}_genomic.fna.gz";
        sys("curl $url", { output => "$fna_f" , die => 0});
        my $result_sketch_dir = "$domain_dir/$organism_name1-taxid$taxid";
        mkdir $result_sketch_dir unless -d $result_sketch_dir;
        if (-f "$fna_f"  && !-f "$result_sketch_dir/$result_basename.msh") {
        print STDERR "Counting number of sequences in file: ";
        my $n_seq = `zgrep -c '^>' $fna_f`;
        chomp $n_seq;
        my $n_bp = `zgrep -v ">" $fna_f | wc | awk '{ printf "%.2f Mbp",(\$3-\$1)/1000/1000}' `;
        chomp $n_bp;
        print STDERR "$n_seq, $n_bp\n";
        sys("mash sketch -k $kmer_size -s $sketch_size -o $result_sketch_dir/$result_basename -I '$assembly_accession $organism_name, $assembly_level assembly [$n_bp, $n_seq seqs]' -C 'taxid $taxid' $fna_f", { check_file=>"$result_sketch_dir/$result_basename.msh" });
        }
    }
    close($F);
}



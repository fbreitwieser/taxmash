# taxmash
Downloads NCBI genomes for Mash and puts taxonomic information into the references comments. Very barebones and slow at the moment, adjust to your own needs. Download sequentially genomes from all RefSeq domains. Meant to be used with `mash taxscreen` (fbreitwieser/Mash).

## Usage 

```sh
# download all Refseq genomes, build min-hashes (takes days)
$ perl dl-genomes.pl run

# Combine all archaeal sketches into one pooled sketch
$ mash paste archaea -l <( find sketches-k21s1000/archaea/ -name '*.msh')

# ID field of the sketch contains assembly info, comment contains taxonomy ID
$ mash info archaea.msh
#Header:
#  Hash function (seed):          MurmurHash3_x64_128 (42)
#  K-mer size:                    21 (64-bit hashes)
#  Alphabet:                      ACGT (canonical)
#  Target min-hashes per sketch:  1000
#  Sketches:                      873
#
#Sketches:
# [Hashes] [Length]  [ID]                                                                                      [Comment]
# 1000     2947156   GCF_003201835.1 Acidianus brierleyi, CompleteGenome assembly [2.95 Mbp, 1 seqs]           taxid 41673
# 1000     2137654   GCF_000213215.1 Acidianus hospitalis W1, CompleteGenome assembly [2.14 Mbp, 1 seqs]       taxid 933801
# 1000     2287077   GCF_003201765.1 Acidianus sulfidivorans JP7, CompleteGenome assembly [2.29 Mbp, 1 seqs]   taxid 619593
 
# Make a test file
$ zgrep -h -A1 '^>' genomes/archaea/*/*.gz | grep -v '^--' > archaea-test.fa

# Download NCBI taxonomy
$ wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
$ tar xvvf taxdump.tar.gz

# Create Kraken-style taxonomic report with fbreitwieser/Mash
$ mash taxscreen archaea.msh archaea-test.msh

%	hashes	taxHashes	hashesDB	taxHashesDB	taxID	rank	name
100.0000	557	0	448901	0	no rank	1	root
100.0000	557	0	448901	0	no rank	131567	  cellular organisms
100.0000	557	3	448901	300	superkingdom	2157	    Archaea
84.5601	471	1	372025	228	phylum	28890	      Euryarchaeota
56.7325	316	0	253546	140	no rank	2290931	        Stenosarchaea group
48.1149	268	38	186986	6523	class	183963	          Halobacteria
24.7756	138	14	71202	1074	order	1644055	            Haloferacales
11.6697	65	9	31337	454	family	1644056	              Haloferacaceae
6.6427	37	18	10148	3304	genus	2251	                Haloferax
1.2567	7	7	799	799	species	1544718	                  Haloferax sp. SB29
0.5386	3	3	55	55	species	2077201	                  Haloferax sp. Atlit-19N
0.3591	2	2	260	260	species	2077203	                  Haloferax sp. Atlit-12N
0.1795	1	0	147	0	species	2246	                  Haloferax volcanii
0.1795	1	1	147	147	no rank	309800	                    Haloferax volcanii DS2
```

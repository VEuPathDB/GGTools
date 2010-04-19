$date = `date`;

if(@ARGV == 1 && @ARGV[0] eq "config") {
    print "\n\nThe folliwing describes the configuration file:\n";
    print "Note: All entries can be absolute path, or relative path to where the RUM_runner.pl script is.\n\n";
    print "1) gene annotation file\n";
    print "   e.g.: indexes/mm9_ucsc_refseq_gene_info.txt\n";
    print "2) bowtie executable, can be relative path to where the RUM_runner.pl script is, or absolute path\n";
    print "   e.g.: /bin/bowtie\n";
    print "3) blat executable, can be relative path to where the RUM_runner.pl script is, or absolute path\n";
    print "   e.g.: /bin/blat\n";
    print "3) mdust executable, can be relative path to where the RUM_runner.pl script is, or absolute path\n";
    print "   e.g.: /bin/mdust\n";
    print "4) bowtie genome index (stem), can be relative path to where the RUM_runner.pl script is, or absolute path\n";
    print "   e.g.: indexes/mm9\n";
    print "5) bowtie transcriptome index (stem), can be relative path to where the RUM_runner.pl script is, or absolute path\n";
    print "   e.g.: indexes/mm9_genes_ucsc_refseq\n";
    print "6) blat genome index, can be relative path to where the RUM_runner.pl script is, or absolute path\n";
    print "   e.g.: indexes/mm9.2bit\n";
    print "7) perl scripts directory, can be relative path to where the RUM_runner.pl script is, or absolute path\n";
    print "   e.g.: scripts\n";
    print "8) 11.ooc file location, can be relative path to where the RUM_runner.pl script is, or absolute path\nIf you don't have one, put anything here and run with the -noooc option.\n";
    print "   e.g: indexes/11.ooc_mm9\n\n";
    exit(0);
}
if(@ARGV < 5) {
    print "\nUsage: <configfile> <readsfile> <output dir> <num chunks> <name> [options]\n\n";
    print "Options: -single    : Data is single-end (default is paired-end).\n";
    print "         -fast      : Run with blat params that run about 3 times faster but a tad less sensitive\n";
    print "         -noooc     : Run without blat ooc file\n";
    print "         -limitNU   : Limits the number of ambiguoust mappers to a max of 100 locations.  If you have short\n";
    print "                      reads and a large genome then this will probably be necessary (45 bases is short for\n";
    print "                      mouse, 70 bases is long, in between it's hard to say).\n";
    print "         -chipseq   : Run in chipseq mode, meaning don't map across splice junctions.\n";
    print "         -qsub      : Use qsub to fire the job off to multiple nodes.  This means you're on a cluster that\n";
    print "                      understands qsub.  The default is to use 'system' which assumes you want to run it on\n";
    print "                      a single machine.  If not using -qsub, you can still break it into multiple chunks, it\n";
    print "                      will just fire each chunk off to a separate processor.  Don't use more chunks than you\n";
    print "                      have processors though, because that will just slow it down.\n\n";
    print "Running RUM_runner.pl with the one argument 'config' will explain how to make the config file.\n\n";
    print "This program writes very large intermediate files.  If you have a large genome such as mouse or human then\n";
    print "it is recommended to run in chunks on a cluster, or a machine with multiple processors.  Running with under\n";
    print "five million reads per chunk is usually best, and getting it under a million reads per chunk will speed things\n";
    print "considerably.\n\n";
    print "You can put an 's' after the number of chunks if they have already been broken\ninto chunks, so as to avoid repeating this time-consuming step.\n\nname is a string that will identify this run.\n  - Use only alphanumeric and underscores, no whitespace or other characters.\n\n";
    exit(0);
}

$configfile = $ARGV[0];
$readsfile = $ARGV[1];
$output_dir = $ARGV[2];
$output_dir =~ s!/$!!;
$numchunks = $ARGV[3];
$name = $ARGV[4];
$name_o = $ARGV[4];
$name =~ s/\s+/_/g;
$name =~ s/^(a-z|A-Z|0-9|_)//g;

if($name ne $name_o) {
    print STDERR "\nWarning: name changed from '$name_o' to '$name'.\n\n";
}
$paired_end = "true";
$fast = "false";
$chipseq = "false";
$limitNU = "false";
$ooc = "true";
$qsub = "false";
if(@ARGV > 5) {
    for($i=5; $i<@ARGV; $i++) {
	$optionrecognized = 0;
	if($ARGV[$i] eq "-single") {
	    $paired_end = "false";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-fast") {
	    $fast = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-chipseq") {
	    $chipseq = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-limitNU") {
	    $limitNU = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-noooc") {
	    $ooc = "false";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-qsub") {
	    $qsub = "true";
	    $optionrecognized = 1;
	}
	if($optionrecognized == 0) {
	    print "\nERROR: option $ARGV[$i] not recognized.\n\n";
	    exit();
	}
    }
}
open(LOGFILE, ">$output_dir/rum.log");
print LOGFILE "start: $date\n";

print "paired_end = $paired_end\n";

if($numchunks =~ /(\d+)s/) {
    $numchunks = $1;
    $fasta_already_fragmented = "true";
} else {
    $fasta_already_fragmented = "false";
}

open(INFILE, $configfile);
$gene_annot_file = <INFILE>;
chomp($gene_annot_file);
$bowtie_exe = <INFILE>;
chomp($bowtie_exe);
$blat_exe = <INFILE>;
chomp($blat_exe);
$mdust_exe = <INFILE>;
chomp($mdust_exe);
$genome_bowtie = <INFILE>;
chomp($genome_bowtie);
$transcriptome_bowtie = <INFILE>;
chomp($transcriptome_bowtie);
$genome_blat = <INFILE>;
chomp($genome_blat);
$scripts_dir = <INFILE>;
$scripts_dir =~ s!/$!!;
chomp($scripts_dir);
$oocfile = <INFILE>;
chomp($oocfile);
close(INFILE);
$head = `head -2 $readsfile | tail -1`;
chomp($head);
@a = split(//,$head);
$readlength = @a;

$head = `head -6 $readsfile`;
$head =~ /seq.(\d+)(.).*seq.(\d+)(.).*seq.(\d+)(.)/s;
$num1 = $1;
$type1 = $2;
$num2 = $3;
$type2 = $4;
$num3 = $5;
$type3 = $6;

if($type1 ne "a") {
    print STDERR "ERROR: the fasta def lines are misformatted.  The first one should end in an 'a'.\n";
    print LOGFILE "Error: fasta file misformatted... The first line should end in an 'a'.\n";
    exit();
}
if($num1 ne "1") {
    print STDERR "ERROR: the fasta def lines are misformatted.  The first one should be '1a'.\n";
    print LOGFILE "Error: fasta file misformatted... The first line should be '1a'.\n";
    exit();
}
if($num2 ne "2" && $paired_end eq "false") {
    print STDERR "ERROR: the fasta def lines are misformatted.  The second one should be '2a' or '1b'\n";
    print STDERR "       depending on whether it is paired end or not.  ";
    print LOGFILE "Error: fasta file misformatted...  The second line should be '2a' or '1b' depending\n";
    print LOGFILE "on whether it is paired end or not..\n";
    if($paired_end eq "true") {
	print STDERR "Note: You are running in paired end mode.\n";
	print LOGFILE "Note: You ran in paired end mode.\n";
    }
    else {
	print STDERR "Note: You are not running in paired end mode.\n";
	print LOGFILE "Note: You ran in unpaired mode.\n";
    }
    exit();
}
if($type2 ne "b" && $paired_end eq "true") {
    print STDERR "ERROR: the fasta def lines are misformatted.  You are in paired end mode so the second\n";
    print STDERR "       one should end in a 'b'.\n";
    print LOGFILE "Error: fasta file misformatted...  You ran in paried end mode so the second\n";
    print LOGFILE "one should end in a 'b'.\n";
    exit();
}
if($type1 eq "a" && $type2 eq "a" && $paired_end eq "true") {
    print STDERR "ERROR: You are running in paired end mode, paired reads should have def\n";
    print STDERR "       lines '>seq.Na' and '>seq.Nb' for N = 1, 2, 3, ... ";
    print LOGFILE "Error: fasta file misformatted...\n";
    print LOGFILE "You are running in paired end mode, paired reads should have def\n";
    print LOGFILE "lines '>seq.Na' and '>seq.Nb' for N = 1, 2, 3, ... ";
    exit();
}
if($paired_end eq "false" && $type1 eq "a" && $type2 eq "a" && ($num1 ne "1" || $num2 ne "2")) {
    print STDERR "ERROR: You ran in unpaired mode, reads should have def\n";
    print STDERR "lines '>seq.Nb' for N = 1, 2, 3, ... ";
    print LOGFILE "Error: fasta file misformatted...\n";
    print LOGFILE "You ran in unpaired mode, reads should have def\n";
    print LOGFILE "lines '>seq.Nb' for N = 1, 2, 3, ... ";
    exit();
}
if($paired_end eq "true" && ($type1 ne "a" || $type2 ne "b")) {
    print STDERR "ERROR: You ran in paired mode, reads should have def\n";
    print STDERR "lines alternating '>seq.Na' and '>seq.Nb' for N = 1, 2, 3, ... ";
    print LOGFILE "Error: fasta file misformatted...\n";
    print LOGFILE "You ran in paired mode, reads should have def\n";
    print LOGFILE "lines alternating '>seq.Na' and '>seq.Nb' for N = 1, 2, 3, ... ";
    exit();
}

if($readlength < 55 && $limitNU eq "false") {
    print STDERR "\n\nWARNING: you have pretty short reads ($readlength bases).  If you have a large\n";
    print STDERR "genome such as mouse or human then the files of ambiguous mappers could grow\n";
    print STDERR "very large, in this case it's recommended to run with the -limitNU option.  You\n";
    print STDERR "can watch the files that start with 'X' and 'Y' to see if they are growing\n";
    print STDERR "larger than 10 gigabytes per million reads at which point you might want to use.\n";
    print STDERR "-limitNU\n\n";
}

if($readlength < 80) {
    $min_size_intersection_allowed = 35;
    $match_length_cutoff = 35;
} else {
    $min_size_intersection_allowed = 45;
    $match_length_cutoff = 50;
}
if($min_size_intersection_allowed >= .8 * $readlength) {
    $min_size_intersection_allowed = int(.6 * $readlength);
    $match_length_cutoff = int(.6 * $readlength);
}

$min_score = $match_length_cutoff - 12;
if($chipseq eq "false") {
    $pipeline_template = `cat pipeline_template.sh`;
} else {
    $pipeline_template = `cat pipeline_template_chipseq.sh`;
}
if($fasta_already_fragmented eq "false") {
    $x = breakup_fasta($readsfile, $numchunks);
}
print "fasta_already_fragmented = $fasta_already_fragmented\n";
print "numchunks = $numchunks\n";
print "readsfile = $readsfile\n";
print "paired_end = $paired_end\n";

for($i=1; $i<=$numchunks; $i++) {
    $pipeline_file = $pipeline_template;
    $pipeline_file =~ s!OUTDIR!$output_dir!gs;
    $pipeline_file =~ s!CHUNK!$i!gs;
    $pipeline_file =~ s!BOWTIEEXE!$bowtie_exe!gs;
    $pipeline_file =~ s!GENOMEBOWTIE!$genome_bowtie!gs;
    $pipeline_file =~ s!BOWTIEEXE!$bowtie_exe!gs;
    $pipeline_file =~ s!READSFILE!$readsfile!gs;
    $pipeline_file =~ s!SCRIPTSDIR!$scripts_dir!gs;
    $pipeline_file =~ s!TRANSCRIPTOMEBOWTIE!$transcriptome_bowtie!gs;
    $pipeline_file =~ s!GENEANNOTFILE!$gene_annot_file!gs;
    $pipeline_file =~ s!MATCHLENGTHCUTOFF!$match_length_cutoff!gs;
    $pipeline_file =~ s!MININTERSECTION!$min_size_intersection_allowed!gs;
    $pipeline_file =~ s!BLATEXE!$blat_exe!gs;
    $pipeline_file =~ s!MDUSTEXE!$mdust_exe!gs;
    $pipeline_file =~ s!GENOMEBLAT!$genome_blat!gs;
    $pipeline_file =~ s!MINSCORE!$min_score!gs;
    $pipeline_file =~ s!READLENGTH!$readlength!gs;
    if($limitNU eq "true") {
	$pipeline_file =~ s! -a ! -k 100 !gs;	
    }
    if($ooc eq "false" || $fast eq "false") {
	$pipeline_file =~ s!-ooc=OOCFILE!!gs;
    }
    if($ooc eq "true") {
	$pipeline_file =~ s!OOCFILE!$oocfile!gs;
    }
    if($fast eq "false") {
	$pipeline_file =~ s!SPEED!-stepSize=5!gs;
    }
    else {
	$pipeline_file =~ s!SPEED!!gs;
    }
    if($paired_end eq "true") {
	$pipeline_file =~ s!PAIREDEND!paired!gs;
    } else {
	$pipeline_file =~ s!PAIREDEND!single!gs;
    }
    $outfile = "pipeline." . $i . ".sh";
    open(OUTFILE, ">$output_dir/$outfile");
    print OUTFILE $pipeline_file;
    close(OUTFILE);

    if($qsub eq "true") {
	`qsub -l mem_free=6G -pe DJ 4 $output_dir/$outfile`;
    }
    else {
	system("/bin/bash $output_dir/$outfile");
    }
}
$doneflag = 0;
while($doneflag == 0) {
    $doneflag = 1;
    for($i=1; $i<=$numchunks; $i++) {
	$logfile = "$output_dir/rum_log.$i";
	if (-e $logfile) {
	    $x = `cat $logfile`;
	    if(!($x =~ /pipeline complete/s)) {
		$doneflag = 0;
	    }
	}
	else {
	    $doneflag = 0;
	}
    }
    if($doneflag == 0) {
	sleep(30);
    }
}
$date = `date`;
print LOGFILE "finished creating RUM_Unique.*/RUM_NU.*: $date\n";
$x = `cp $output_dir/RUM_Unique.1 $output_dir/RUM_Unique`;
for($i=2; $i<=$numchunks; $i++) {
    $x = `cat $output_dir/RUM_Unique.$i >> $output_dir/RUM_Unique`;
}
$x = `cp $output_dir/RUM_NU.1 $output_dir/RUM_NU`;
for($i=2; $i<=$numchunks; $i++) {
    $x = `cat $output_dir/RUM_NU.$i >> $output_dir/RUM_NU`;
}
print LOGFILE "finished creating RUM_Unique/RUM_NU: $date\n";
print LOGFILE "starting M2C: $date\n";
$M2C_log = "M2C_$name" . ".log";
$shellscript = "#!/bin/sh\n";
$shellscript = $shellscript . "echo making bed > $output_dir/$M2C_log\n";
$shellscript = $shellscript . "echo `date` > $output_dir/$M2C_log\n";
$shellscript = $shellscript . "perl $scripts_dir/make_bed.pl $output_dir/RUM_Unique $output_dir/RUM_Unique.bed\n";
$shellscript = $shellscript . "echo starting M2C > $output_dir/$M2C_log\n";
$shellscript = $shellscript . "echo `date` > $output_dir/$M2C_log\n";
$shellscript = $shellscript . "java -Xmx2000m M2C $output_dir/RUM_Unique.bed $output_dir/RUM_$name -ucsc -name \"$name\" -chunks 4\n";
$shellscript = $shellscript . "echo starting to quantify features > $output_dir/$M2C_log\n";
$shellscript = $shellscript . "echo `date` >> $output_dir/$M2C_log\n";
$shellscript = $shellscript . "perl $scripts_dir/quantify_one_sample.pl $output_dir/RUM_$name";
$shellscript = $shellscript . ".cov $gene_annot_file -zero -open > $output_dir/feature_quantifications_$name\n";
$shellscript = $shellscript . "echo finished > $output_dir/$M2C_log\n";
$shellscript = $shellscript . "echo `date` >> $output_dir/$M2C_log\n";
$str = "m2c_$name" . ".sh";
open(OUTFILE2, ">$output_dir/$str");
print OUTFILE2 $shellscript;
close(OUTFILE2);

if($qsub eq "true") {
    `qsub -l mem_free=6G -pe DJ 4 $output_dir/$str`;
}
else {
    system("/bin/bash $output_dir/$str");
}

$doneflag = 0;
while($doneflag == 0) {
    $doneflag = 1;
    if (-e "$output_dir/$M2C_log") {
	$x = `cat $output_dir/$M2C_log`;
	if(!($x =~ /finished/s)) {
	    $doneflag = 0;
	}
    }
    else {
	$doneflag = 0;
    }
    if($doneflag == 0) {
	sleep(30);
    }
}

$date = `date`;
print LOGFILE "pipeline finished: $date\n";
close(LOGFILE);

sub breakup_fasta () {
    ($fastafile, $numpieces) = @_;
    open(INFILE, $fastafile);
    $filesize = `wc -l $fastafile`;
    chomp($filesize);
    $filesize =~ s/^\s+//;
    $filesize =~ s/\s.*//;
    $numseqs = $filesize / 2;
    $piecesize = int($numseqs / $numpieces);
    print LOGFILE "processing in $numchunks pieces of approx $piecesize size each.\n";
    if($piecesize % 2 == 1) {
	$piecesize++;
    }
    $bflag = 0;
    for($i=1; $i<$numpieces; $i++) {
	$outfilename = $fastafile . "." . $i;
	open(OUTFILE, ">$outfilename");
	for($j=0; $j<$piecesize; $j++) {
	    $line = <INFILE>;
	    chomp($line);
	    $line =~ s/\^M$//s;
	    $line =~ s/[^ACGTNab]$//s;
	    print OUTFILE "$line\n";
	    $line = <INFILE>;
	    chomp($line);
	    $line =~ s/\^M$//s;
	    $line =~ s/[^ACGTNab]$//s;
	    print OUTFILE "$line\n";
	}
	close(OUTFILE);
    }
    $outfilename = $fastafile . "." . $numpieces;
    open(OUTFILE, ">$outfilename");
    while($line = <INFILE>) {
	print OUTFILE $line;
    }
    close(OUTFILE);
    return 0;
}
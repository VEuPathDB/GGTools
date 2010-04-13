$| = 1;
# blat run on forward/reverse reads separately, reported in order
# first make hash 'blathits' which is all alignments of the read that we would accept (indexed by t=0,1 for forward/reverse)
# then make array 'read_mapping_to_genome_blatoutput' which has all things that are within 5 bases of the longest alignment in 'blathits' (also indexed by t=0,1)
# then find things that we would keep if only the forward or reverse map, put them in 'one_dir_only_candidate' (also indexed by t=0,1)
# then go through array 'read_mapping_to_genome_blatoutput' to find things that are consistent mappers, put in array 'consistent_mappers'
# then go through 'consistent_mappers' and if a substantial overlap between all members then report the overlap to file of unique mappers blatU
# otherwise report to file of non unique mappers blatNU

# Blat should be run with the following parameters for maximum sensitivity:
# -ooc=11.ooc -minScore=M -minIdentity=93 -stepSize=5 -repMatch=2253
# where M = $match_length_cutoff - 12;
# Blat should be run with the following parameters for speed:
# -ooc=11.ooc -minScore=M -minIdentity=93

if(@ARGV < 6) {
    die "
Usage: parse_blat_out.pl <seq file> <blat file> <mdust file> <blat unique outfile> <blat nu outfile> <readlength> [options]

Where: <seq file> is a the fasta file of reads output from make_unmapped_file.pl

       <blat file> is the file output from blat being run on <seq file>

       <mdust file> is the file output from mdust being run on <seq file>

       <blat unique outfile> is the name of the output file of unique blat mappers

       <blat nu outfile> is the name of the output file of non-unique blat mappers

       <readlength> is the length of the read

Option: 
       -maxpairdist N : N is an integer greater than zero representing
                        the furthest apart the forward and reverse reads
                        can be.  They could be separated by an exon/exon
                        junction so this number can be as large as the largest
                        intron.  Default value = 500,000

       -chipseq       : set this flag is aligning chipseq data

* All three files must be in order by sequence number, and if paired end the a's come before the b's

";}

$readlength = $ARGV[5];
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

$seqfile = $ARGV[0];
$blatfile = $ARGV[1];
$mdustfile = $ARGV[2];
$outfile1 = $ARGV[3];
$outfile2 = $ARGV[4];

open(BLATHITS, $blatfile);  # The file of BLAT output
open(SEQFILE, $seqfile);
$head = `head -1 $seqfile`;
$head2 = `head -3 $seqfile`;
if($head2 =~ /seq.\d+b/) {
    $paired_end = "true";
} else {
    $paired_end = "false";
}
$head =~ /seq.(\d+)/;
$first_seq_num = $1;
$tail = `tail -1 $blatfile`;
@a = split(/\t/,$tail);
$last_seq_num = $a[9];
$last_seq_num =~ s/[^\d]//g;
open(MDUST, $mdustfile);  # the file of mdust output
open(RESULTS, ">$outfile1");
open(RESULTS2, ">$outfile2");

$max_distance_between_paired_reads = 500000;
$chipseq = 'false';
$num_blocks_allowed = 1000;
for($i=6; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-maxpairdist") {
	$i++;
	$max_distance_between_paired_reads = $ARGV[$i];
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-chipseq") {
	$chipseq = 'true';
	$num_blocks_allowed = 1;
	$optionrecognized = 1;
    }

    if($optionrecognized == 0) {
	die "\nERROR: option '$ARGV[$i-1] $ARGV[$i]' not recognized\n";
    }
}

# NOTE: insertions instead are indicated in the final output file with the "+" notation
for($seq_count=$first_seq_num; $seq_count<=$last_seq_num; $seq_count++) {
    if($seq_count % 100000 == 0) {
	print "$seq_count\n";
    }
    if($seq_count == $first_seq_num) {
	$line = <BLATHITS>;
	chomp($line);
	while(($line =~ /--------------------------------/) || ($line =~ /psLayout/) || ($line =~ /blockSizes/) || ($line =~ /match\s+match/) || (!($line =~ /\S/))) {
	    $line = <BLATHITS>;
	    chomp($line);
	}
	@a = split(/\t/,$line);
	@a_x = split(/\t/,$line);
	$seqname = $a[9];
	$seqnum = $seqname;
	$seqnum =~ s/[^\d]//g;
	$seqa_temp = <SEQFILE>;
	chomp($seqa_temp);
	$seqa_temp =~ s/\^M$//;
	$seqa_temp =~ s/[^ACGTNab]$//;
	$mdust_temp = <MDUST>;
	chomp($mdust_temp);
	$mdust_temp =~ s/\^M$//;
	$mdust_temp =~ s/[^ACGTNab]$//;
    }
    $seqa_temp =~ /seq.(\d+)/;
    $seq_count = $1;       # this way we skip over things that aren't in <seq file>
    $seqa_temp = <SEQFILE>;
    chomp($seqa_temp);
    $seqa_temp =~ s/\^M$//;
    $seqa_temp =~ s/[^ACGTNab]$//;
    $seqa = "";
    while(!($seqa_temp =~ /^>/)) {
	$seqa_temp =~ s/[^A-Z]//gs;
	$seqa = $seqa . $seqa_temp;
	$seqa_temp = <SEQFILE>;
	chomp($seqa_temp);
	$seqa_temp =~ s/\^M$//;
	$seqa_temp =~ s/[^ACGTNab]$//;
	if($seqa_temp eq '') {
	    last;
	}
    }
    if($paired_end eq "true") {
	$seqb_temp = <SEQFILE>;
	chomp($seqb_temp);
	$seqb_temp =~ s/\^M$//;
	$seqb_temp =~ s/[^ACGTNab]$//;
	$seqb = "";
	$seqb_temp =~ s/[^A-Z]//gs;
	while(!($seqb_temp =~ /^>/)) {
	    $seqb = $seqb . $seqb_temp;
	    $seqb_temp = <SEQFILE>;
	    chomp($seqb_temp);
	    $seqb_temp =~ s/\^M$//;
	    $seqb_temp =~ s/[^ACGTNab]$//;
	    if($seqb_temp eq '') {
		last;
	    }
	}
	$seqa_temp = $seqb_temp;
    }

    $mdust_temp = <MDUST>;
    chomp($mdust_temp);
    $mdust_temp =~ s/\^M$//;
    $mdust_temp =~ s/[^ACGTNab]$//;
    $dust_output = "";
    while(!($mdust_temp =~ /^>/)) {
	$dust_output = $dust_output . $mdust_temp;
	$mdust_temp = <MDUST>;
	chomp($mdust_temp);
	$mdust_temp =~ s/\^M$//;
	$mdust_temp =~ s/[^ACGTNab]$//;
	if($mdust_temp eq '') {
	    last;
	}
    }
    $sn = "seq.$seq_count" . "a";
    $Ncount{$sn} = ($dust_output =~ tr/N//);
    $cutoff{$sn} = $match_length_cutoff + $Ncount{$sn};
    if($cutoff{$sn} > $a_x[10] - 2) {
	$cutoff{$sn} = $a_x[10] - 2;
    }
    if($paired_end eq "true") {
	$mdust_temp = <MDUST>;
	chomp($mdust_temp);
	$mdust_temp =~ s/\^M$//;
	$mdust_temp =~ s/[^ACGTNab]$//;
	$dust_output = "";
	while(!($mdust_temp =~ /^>/)) {
	    $dust_output = $dust_output . $mdust_temp;
	    $mdust_temp = <MDUST>;
	    chomp($mdust_temp);
	    $mdust_temp =~ s/\^M$//;
	    $mdust_temp =~ s/[^ACGTNab]$//;
	    if($mdust_temp eq '') {
		last;
	    }
	}
	$sn = "seq.$seq_count" . "b";
	$Ncount{$sn} = ($dust_output =~ tr/N//);
	$cutoff{$sn} = $match_length_cutoff + $Ncount{$sn};
	if($cutoff{$sn} > $a_x[10] - 2) {
	    $cutoff{$sn} = $a_x[10] - 2;
	}
    }
    @a = split(/\t/,$line);
    @a_x = split(/\t/,$line);
    while($seqnum == $seq_count) {
	$LENGTH = getTotalSizeFromBlockSizes($a[18]);
	$SCORE = $LENGTH - $a[1]; # This is the number of matches minus the number of mismatches, ignoring N's and gaps
	if($SCORE > $cutoff{$seqname}) {   # so match is at least cutoff long (and this cutoff was set to be longer if there are a lot of N's (bad reads or low complexity masked by dust)
	    if($a[11] <= 1) {   # so match starts at position zero or one in the query (allow '1' because first base can tend to be an N or low quality)
		if($a[4] <= 1) { # then the aligment has at most one gap in the query, allowing for an insertion in the sample, throw out this alignment otherwise (we don't believe two separate insertions in such a short span).
		    if($Ncount{$a[9]} <= ($a[10] / 2) || $a[17] <= 3) { # IF SEQ IS MORE THAN 50% LOW COMPLEXITY, DON'T ALLOW MORE THAN 3 BLOCKS, OTHERWISE GIVING IT TOO MUCH OPPORTUNITY TO MATCH BY CHANCE.  
			if($a[17] <= $num_blocks_allowed) { # NEVER ALLOW MORE THAN $num_blocks_allowed blocks, which is set to 1 for chipseq, and 1000 (the equiv of infinity) for rnaseq
			    # at this point we know it's a prefix match starting at pos 0 or 1 and with at most one gap in the query, and if low comlexity then not too fragemented...
			    $gap_flag = 0;
			    if($a[4] == 1) { # there's a gap in the query, be stricter about allowing it
				if($a[1] > 2) { # ONLY 2 MISMATCHES
				    $gap_flag = 1;
				}
				if($a[12] < .85 * $a[10]) { # LONGER LENGTH MATCH (at least 85% length of read)
				    $gap_flag = 1;
				}
				if($a[6] > 1) { # at most one gap in the target
				    $gap_flag = 1;
				}
				$a[18]=~s/,$//;
				$a[20]=~s/,$//;
				@A=split(/,/,$a[18]);
				@B=split(/,/,$a[20]);
				for($k=0;$k<@A-1;$k++) { # any gap in the target must be at least 32 bases
				    if(($B[$k+1]-$A[$k]-$B[$k]<32) && ($B[$k+1]-$A[$k]-$B[$k]>0)) {
					$gap_flag = 1;
				    }
				}
				if($a[5] > 3) { # gap in the query can be at most 3 bases
				    $gap_flag = 1;
				}
				@qs = split(/,/,$a[19]);
				@bs = split(/,/,$a[18]);
				
				for($h=0; $h<@qs-1; $h++) { # gap at least 8 bases from the end of a block
				    if($qs[$h]+$bs[$h] < $qs[$h+1]) {
					if($bs[$h] < 8 || $bs[$h+1] < 8) {
					    $gap_flag = 1;
					}
				    }
				}
				if($a[4]+$a[6] >= @qs) { # this makes sure gap in query and target not in same place
				    $gap_flag = 1;
				}
			    }
			    if($gap_flag == 0) { # IF GOT TO HERE THEN READ PASSED ALL CRITERIA FOR A MATCH
				$cnt{$seqname} = $cnt{$seqname} + 0;
				$blathits{$seqname}[$cnt{$seqname}][0] = $SCORE;  # the score of the match (see def above)
				$blathits{$seqname}[$cnt{$seqname}][1] = $a[8];   # the strand
				$blathits{$seqname}[$cnt{$seqname}][2] = $a[13];  # the name of the target seq
				$blathits{$seqname}[$cnt{$seqname}][3] = $a[18];  # the block sizes
				$blathits{$seqname}[$cnt{$seqname}][4] = $a[20];  # the t starts
				$blathits{$seqname}[$cnt{$seqname}][5] = $a[1];   # the number of mismatches (not including N's)
				$blathits{$seqname}[$cnt{$seqname}][6] = $a[19];  # the q starts
				
#			    print "blathits{$seqname}[$cnt{$seqname}][0]=$blathits{$seqname}[$cnt{$seqname}][0]\n";
#			    print "blathits{$seqname}[$cnt{$seqname}][1]=$blathits{$seqname}[$cnt{$seqname}][1]\n";
#			    print "blathits{$seqname}[$cnt{$seqname}][2]=$blathits{$seqname}[$cnt{$seqname}][2]\n";
#			    print "blathits{$seqname}[$cnt{$seqname}][3]=$blathits{$seqname}[$cnt{$seqname}][3]\n";
#			    print "blathits{$seqname}[$cnt{$seqname}][4]=$blathits{$seqname}[$cnt{$seqname}][4]\n";
#			    print "blathits{$seqname}[$cnt{$seqname}][5]=$blathits{$seqname}[$cnt{$seqname}][5]\n";
#			    print "blathits{$seqname}[$cnt{$seqname}][6]=$blathits{$seqname}[$cnt{$seqname}][6]\n";
				$N = @{$blathits{$seqname}};
				if($maxlength{$seqname}+0 < $a[12]) {
				    $maxlength{$seqname} = $a[12];
				}
				if($a[4] == 1) { # then query has a gap, write this to the insertions file I
				    $gapsize = $a[5];
				    $a[18] =~ s/,$//;
				    $a[19] =~ s/,$//;
				    $a[20] =~ s/,$//;
				    @blocksizes = split(/,/,$a[18]);
				    @qStarts = split(/,/,$a[19]);
				    @tStarts = split(/,/,$a[20]);
				    $n = @blocksizes;
				    for($block=0; $block < $n-1; $block++) {
					if($blocksizes[$block] + $qStarts[$block] < $qStarts[$block+1]) {
					    $insertion_target_coord = $blocksizes[$block] + $tStarts[$block];
					    if($seqname =~ /a/) {
						$temp = $seqa;
					    }
					    if($seqname =~ /b/) {
						$temp = $seqb;
					    }
					    if($a[8] eq "+") {
						@s = split(//,$temp);
					    }
					    else {
						@s2 = split(//,$temp);
						$n2 = @s2-1;
						$TMP = "";
						for($i=$n2; $i>=0; $i--) {
						    $flag = 0;
						    if($s2[$i] eq 'A') {
							$s[$n2 - $i] =  "T";
							$flag = 1;
							$TMP = $TMP . "T";
						    }
						    if($s2[$i] eq 'T') {
							$s[$n2 - $i] =  "A";
							$flag = 1;
							$TMP = $TMP . "A";
						    }
						    if($s2[$i] eq 'G') {
							$s[$n2 - $i] =  "C";
							$flag = 1;
							$TMP = $TMP . "C";
						    }
						    if($s2[$i] eq 'C') {
							$s[$n2 - $i] =  "G";
							$flag = 1;
							$TMP = $TMP . "G";
						    }
						    if($flag == 0) {
							$s[$n2 - $i] =  $s2[$i];
						    }
						}
					    }
					    $insertion = "";
					    for($c=0; $c<$a[5]; $c++) {
						$insertion = $insertion . "$s[$c + $qStarts[$block] + $blocksizes[$block]]";
					    }
					    $inscoord_temp = $insertion_target_coord + 1;
					    $a[13] =~ /chr(.*):/;
					    $chr = $1;
					    $insertion = "chr" . $chr . ":" . $insertion_target_coord . ":" . $insertion . ":" . $inscoord_temp . "\n";
					    $blathits{$seqname}[$cnt{$seqname}][7] = $insertion;
					    $block = $n;
					}
				    }
				}
				$cnt{$seqname}++;  # this is the number of hits to this seq satisfying all criteria
			    }
			}
		    }
		}
	    }
	}
	$line = <BLATHITS>;
	chomp($line);
	while(($line =~ /--------------------------------/) || ($line =~ /psLayout/) || ($line =~ /blockSizes/) || ($line =~ /match\s+match/) || (!($line =~ /\S/))) {
	    $line = <BLATHITS>;
	    if($line eq '') {
		last;
	    }
	    chomp($line);
	}	    
	@a = split(/\t/,$line);
	@a_x = split(/\t/,$line);
	$seqname = $a[9];
	$seqnum = $seqname;
	$seqnum =~ s/[^\d]//g;
    }
    $sname[0] = "seq." . $seq_count . "a";
    $sname[1] = "seq." . $seq_count . "b";

    for($t=0; $t<2; $t++) {  # $t=0 for the 'a' (forwad) reads, $t=1 for the 'b' (reverse) reads
	$cnt2=0;
	$N = @{$blathits{$sname[$t]}};
	for($i1=0; $i1<$N; $i1++) {
	    if($blathits{$sname[$t]}[$i1][0] >= $maxlength{$sname[$t]} - 10) {
		$chr = $blathits{$sname[$t]}[$i1][2];  # Should have the span, but the 'if' below allows it to not
		if($chr =~ /:(\d+)/) {
		    $start = $1;
		    $chr =~ s/:.*//;
		}
		else {
		    $start = 1;
		}
		@a0 = split(/,/,$blathits{$sname[$t]}[$i1][4]);
		@b = split(/,/,$blathits{$sname[$t]}[$i1][3]);
		@qs = split(/,/,$blathits{$sname[$t]}[$i1][6]);
		$l = $start + $a0[0];
		$e = $l + $b[0] - 1;
		$loc = "$chr\t$l-$e";
		for($j=1; $j<@a0; $j++) {
		    $l = $start + $a0[$j];
		    $e = $l + $b[$j] - 1;
		    $loc = $loc . ", $l-$e";
		}
		# loc is correct, wether the query has a gap or not
		# but loc might have spans with no space between them if a gap in the query
		# the following will fix that:
		$loc2 = $loc;
		$loc2 =~ s/.*\t//;
		@L = split(/, /,$loc2);
		$fixedloc = "";
		$LL = @L;
		for($j=0; $j<$LL; $j++) {
		    @x = split(/-/,$L[$j]);
		    @y = split(/-/,$L[$j+1]);
		    if($x[1] == ($y[0]-1)) {
			$fixedloc = $fixedloc . "$x[0]-$y[1], ";
			$j++;
		    }
		    else {
			$fixedloc = $fixedloc . "$x[0]-$x[1], ";
		    }
		}
		$loc =~ s/\t.*//;
		$loc = $loc . "\t$fixedloc";
		$loc =~ s/, $//;
		$read_mapping_to_genome_blatoutput[$t][$cnt2] = "$sname[$t]\t$loc\t$blathits{$sname[$t]}[$i1][0]\t$blathits{$sname[$t]}[$i1][1]\t$blathits{$sname[$t]}[$i1][2]\t$blathits{$sname[$t]}[$i1][3]\t$blathits{$sname[$t]}[$i1][4]\t$blathits{$sname[$t]}[$i1][5]\t$blathits{$sname[$t]}[$i1][6]\t$blathits{$sname[$t]}[$i1][7]\t$i1";

# 0: sname
# 1: chr
# 2: spans (note chr and spans are combined in $loc with a tab between them)
# 3: length of the prefix
# 4: strand
# 5: name of the target seq
# 6: block sizes
# 7: t-starts
# 8: num mismatches
# 9: q-starts
# 10: the number of the (kept) blat hit, starting counting at 0

		$cnt2++;
	    }
	}
    }

    for($t=0; $t<2; $t++) {  # $t=0 for the 'a' (forwad) reads, $t=1 for the 'b' (reverse) reads
	$max_length = 0;
	$secondmax_length = 0;
	$N = @{$read_mapping_to_genome_blatoutput[$t]};
	$maxkey = "";
	$secondmaxkey = "";
	$maxkey_nummismatch = 0;
	$secondmaxkey_nummismatch = 0;
	for($c=0; $c<$N; $c++) {
	    $key = $read_mapping_to_genome_blatoutput[$t][$c];
	    @a2 = split(/\t/,$key);
	    if($a2[3] > $max_length) {
		$max_length = $a2[3]; # note: you might think index should be a 2, but $loc has a tab in it
		$maxkey_nummismatch = $a2[8];
		$maxkey = $key;
	    }
	}
# make the array 'read_mapping_to_genome_coords' which has things in 'read_mapping_to_genome_blatoutput'
# that are within five bases of the longest, mapped to genomic coords
	$c2=0;
	for($c=0; $c<$N; $c++) {
	    $key = $read_mapping_to_genome_blatoutput[$t][$c];
	    @a4 = split(/\t/,$key);
	    if($a4[3] > $max_length - 5 && $a4[8] <= $maxkey_nummismatch + 2) {
		if($sname[$t] =~ /a/) {
		    $seq = getsequence($a4[6], $a4[9], $a4[4], $seqa);
		}
		else {
		    $seq = getsequence($a4[6], $a4[9], $a4[4], $seqb);
		}
		$read_mapping_to_genome_coords[$t][$c2] = "$a4[0]\t$a4[1]\t$a4[2]\t$seq";
		$read_mapping_to_genome_pairing_candidate[$t][$c2] = $read_mapping_to_genome_blatoutput[$t][$c];
		$c2++;
	    }
	}
	for($c=0; $c<$N; $c++) {
	    $key = $read_mapping_to_genome_blatoutput[$t][$c];
	    if($key ne $maxkey) {
		@a3 = split(/\t/,$key);
		if($a3[3] > $secondmax_length) {
		    $secondmax_length = $a3[3];
		    $secondmaxkey_nummismatch = $a2[8];
		    $secondmaxkey = $key;
		}
	    }
	}

# NOTE: The following keeps track of things that could be reported as unique matches of forward/reverse
# reads in the case that the paired read does not map, a case that would be missed by the above, 
# basically if the longest read is not more than 5 bases longer than the second longest but is at 
# least two longer and has fewer mismatches, then we keep it as the best candidate

	@a5 = split(/\t/,$secondmaxkey);
	if($secondmax_length < $max_length) {
	    @a6 = split(/\t/,$maxkey);
	    if($sname[$t] =~ /a/) {
		$seq = getsequence($a6[6], $a6[9], $a6[4], $seqa);
	    }
	    else {
		$seq = getsequence($a6[6], $a6[9], $a6[4], $seqb);
	    }
	    $one_dir_only_candidate[$t] = "$a6[0]\t$a6[1]\t$a6[2]\t$seq";
	}
    }

    $numa = @{$read_mapping_to_genome_coords[0]} + 0;
    $numb = @{$read_mapping_to_genome_coords[1]} + 0;

    if($numa == 1 && $numb == 0) { # unique forward match, no reverse
	print RESULTS "$read_mapping_to_genome_coords[0][0]\n";
    }
    if($numa > 1 && $numb == 0) {
	$unique = 0;
	if($one_dir_only_candidate[0] =~ /\S/) {
	    print RESULTS "$one_dir_only_candidate[0]\n";
	    $unique = 1;
	}
	undef @spans;
	undef %CHRS;
	if($unique == 0) {
	    $nchrs = 0;
	    for($i=0; $i<$numa; $i++) {
		@B1 = split(/\t/, $read_mapping_to_genome_coords[0][$i]);
		$spans[$i] = $B1[2];
		$seq_temp = $B1[3];
		$CHRS{$B1[1]}++;
	    }
	    $nchrs = 0;
	    foreach $ky (keys %CHRS) {
		$nchrs++;
		$CHR = $ky;
	    }
	    $str = intersect(\@spans, $seq_temp);
	    if($str ne "0\t" && $nchrs == 1) {
		$str =~ s/^(\d+)\t/$CHR\t/;
		$size = $1;
		if($size >= $min_size_intersection_allowed) {
		    @ss = split(/\t/,$str);
		    $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
		    print RESULTS "seq.$seq_count";
		    print RESULTS "a\t$ss[0]\t$ss[1]\t$seq_new\n";
		    $unique = 1;
		}
	    }
	}
	undef @B1;
	undef @ss;
	undef @spans;
	if($unique == 0) {
	    for($i=0; $i<$numa; $i++) {
		print RESULTS2 "$read_mapping_to_genome_coords[0][$i]\n";
	    }
	}
    }
    if($numb == 1 && $numa == 0) { # unique reverse match, no forward
	print RESULTS "$read_mapping_to_genome_coords[1][0]\n";
    }
    if($numa == 0 && $numb > 1) {
	$unique = 0;
	if($one_dir_only_candidate[1] =~ /\S/) {
	    print RESULTS "$one_dir_only_candidate[1]\n";
	    $unique = 1;
	}
	undef @spans;
	undef %CHRS;
	if($unique == 0) {
	    $nchrs = 0;
	    for($i=0; $i<$numb; $i++) {
		@B1 = split(/\t/, $read_mapping_to_genome_coords[1][$i]);
		$spans[$i] = $B1[2];
		$seq_temp = $B1[3];
		$CHRS{$B1[1]}++;
	    }
	    $nchrs = 0;
	    foreach $ky (keys %CHRS) {
		$nchrs++;
		$CHR = $ky;
	    }
	    $str = intersect(\@spans, $seq_temp);
	    if($str ne "0\t" && $nchrs == 1) {
		$str =~ s/^(\d+)\t/$CHR\t/;
		$size = $1;
		if($size >= $min_size_intersection_allowed) {
		    @ss = split(/\t/,$str);
		    $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
		    print RESULTS "seq.$seq_count";
		    print RESULTS "b\t$ss[0]\t$ss[1]\t$seq_new\n";
		    $unique = 1;
		}
	    }
	}
	undef @B1;
	undef @ss;
	undef @spans;
	if($unique == 0) {
	    for($i=0; $i<$numb; $i++) {
		print RESULTS2 "$read_mapping_to_genome_coords[1][$i]\n";
	    }
	}
    }
    if($numa > 0 && $numb > 0 && $numa * $numb < 1000000) {  # this is one very big case within which we search
                                                             # for consistent a/b mappers
	for($i=0; $i<$numa; $i++) {
	    @B1 = split(/\t/, $read_mapping_to_genome_pairing_candidate[0][$i]);
	    $achr = $B1[1];
	    $astrand = $B1[4];
	    $aseq = $read_mapping_to_genome_coords[0][$i];
	    $aseq =~ s/.*\t//;
	    @aexons = split(/, /,$B1[2]);
	    undef @astarts;
	    undef @aends;
	    for($e=0; $e<@aexons; $e++) {
		@c = split(/-/,$aexons[$e]);
		$astarts[$e] = $c[0];
		$aends[$e] = $c[1];
	    }
	    $astart = $astarts[0];
	    $aend = $aends[$e-1];
	    for($j=0; $j<$numb; $j++) {
		@B1 = split(/\t/, $read_mapping_to_genome_pairing_candidate[1][$j]);
		$bchr = $B1[1];
		$bstrand = $B1[4];
		$bseq = $read_mapping_to_genome_coords[1][$j];
		$bseq =~ s/.*\t//;
		@bexons = split(/, /,$B1[2]);
		undef @bstarts;
		undef @bends;
		for($e=0; $e<@bexons; $e++) {
		    @c = split(/-/,$bexons[$e]);
		    $bstarts[$e] = $c[0];
		    $bends[$e] = $c[1];
		}
		$bstart = $bstarts[0];
		$bend = $bends[$e-1];
		if($achr eq $bchr) {
		    if($astrand eq "+" && $bstrand eq "-" && ($aend < $bstart-1) && ($bstart - $aend <= $max_distance_between_paired_reads)) {
			$consistent_mappers{"$read_mapping_to_genome_coords[0][$i]\n$read_mapping_to_genome_coords[1][$j]"}++;
		    }
		    if($astrand eq "-" && $bstrand eq "+" && ($bend < $astart-1) && ($astart - $bend <= $max_distance_between_paired_reads)) {
			$consistent_mappers{"$read_mapping_to_genome_coords[0][$i]\n$read_mapping_to_genome_coords[1][$j]"}++;
		    }
		    if(($astrand eq "-") && ($bstrand eq "+") && ($bend >= $astart - 1) && ($astart >= $bstart) && ($aend >= $bend)) {
			# this is a hack to switch the a and b reads so the following if can take care of both cases
			$cstrand = $astrand;
			$astrand = $bstrand;
			$bstrand = $cstrand;
			$cstart = $astart;
			$astart = $bstart;
			$bstart = $cstart;
			$cend = $aend;
			$aend = $bend;
			$bend = $cend;
			@cstarts = @astarts;
			@astarts = @bstarts;
			@bstarts = @cstarts;
			@cends = @aends;
			@aends = @bends;
			@bends = @cends;
			$cseq = $aseq;
			$aseq = $bseq;
			$bseq = $cseq;
		    }
		    if(($astrand eq "+") && ($bstrand eq "-") && ($aend == $bstart-1)) {
			$num_exons_merged = @astarts + @bstarts - 1;
			undef @mergedstarts;
			undef @mergedends;
			$H=0;
			for($e=0; $e<@astarts; $e++) {
			    $mergedstarts[$H] = @astarts[$e];
			    $H++;
			}
			for($e=1; $e<@bstarts; $e++) {
			    $mergedstarts[$H] = @bstarts[$e];
			    $H++;
			}
			$H=0;
			for($e=0; $e<@aends-1; $e++) {
			    $mergedends[$H] = @aends[$e];
			    $H++;
			}
			for($e=0; $e<@bends; $e++) {
			    $mergedends[$H] = @bends[$e];
			    $H++;
			}
			$num_exons_merged = $H;
			$merged_length = $mergedends[0]-$mergedstarts[0]+1;
			$merged_spans = "$mergedstarts[0]-$mergedends[0]";
			for($e=1; $e<$num_exons_merged; $e++) {
			    $merged_length = $merged_length + $mergedends[$e]-$mergedstarts[$e]+1;
			    $merged_spans = $merged_spans . ", $mergedstarts[$e]-$mergedends[$e]";
			}
			$merged_seq = $aseq . $bseq;
			$consistent_mappers{"seq.$seq_count\t$achr\t$merged_spans\t$merged_seq"}++;
		    }
		    if(($astrand eq "+") && ($bstrand eq "-") && ($aend >= $bstart) && ($bstart >= $astart) && ($bend >= $aend)) {
			$f = 0;
			$consistent = 1;
			$flag = 0;
			while($flag == 0 && $f < @astarts) {
			    if($bstart >= $astarts[$f] && $bstart <= $aends[$f]) {
				$first_overlap_exon = $f;  # this index is relative to the a read
				$flag = 1;
			    }
			    else {
				$f++;
			    }
			}
			$f = @bstarts-1;
			if($flag != 1) {
			    $consistent = 0;
			}
			$flag = 0;
			while($flag == 0 && $f >= 0) {
			    if($aend >= $bstarts[$f] && $aend <= $bends[$f]) {
				$last_overlap_exon = $f;  # this index is relative to the b read
				$flag = 1;
			    }
			    else {
				$f--;
			    }
			}
			if($flag != 1) {
			    $consistent = 0;
			}
			
			$NT = @astarts;
			$NT = @bstarts;
			$overlap = 0;
			if($first_overlap_exon < @astarts-1 || $last_overlap_exon > 0) {
			    if($bends[0] != $aends[$first_overlap_exon]) {
				$consistent = 0;
			    }
			    if($astarts[@astarts-1] != $bstarts[$last_overlap_exon]) {
				$consistent = 0;
			    }
			    $b_exon_counter = 1;
			    for($e=$first_overlap_exon+1; $e < @astarts-1; $e++) {
				if($astarts[$e] != $bstarts[$b_exon_counter] || $aends[$e] != $bends[$b_exon_counter]) {
				    $consistent = 0;
				}
				$b_exon_counter++;
			    }
			}
			if($consistent == 1) {
			    $NN = @astarts;
			    $MM = @bstarts;
			    $aseq =~ s/://g;
			    $bseq =~ s/://g;
			    $num_exons_merged = @astarts + @bstarts - $last_overlap_exon - 1;
			    undef @mergedstarts;
			    undef @mergedends;
			    for($e=0; $e<@astarts; $e++) {
				$mergedstarts[$e] = @astarts[$e];
			    }
			    for($e=0; $e<@astarts-1; $e++) {
				$mergedends[$e] = @aends[$e];
			    }
			    $mergedends[@astarts-1] = $bends[$last_overlap_exon];
			    $E = @astarts-1;
			    for($e=$last_overlap_exon+1; $e<@bstarts; $e++) {
				$E++;
				$mergedstarts[$E] = $bstarts[$e];
				$mergedends[$E] = $bends[$e];
			    }
			    $num_exons_merged = $E+1;
			    $merged_length = $mergedends[0]-$mergedstarts[0]+1;
			    $merged_spans = "$mergedstarts[0]-$mergedends[0]";
			    for($e=1; $e<$num_exons_merged; $e++) {
				$merged_length = $merged_length + $mergedends[$e]-$mergedstarts[$e]+1;
				$merged_spans = $merged_spans . ", $mergedstarts[$e]-$mergedends[$e]";
			    }
			    $aseq_temp = $aseq;
			    $aseq_temp =~ s/\+.*\+//g;
			    @s1 = split(//,$aseq_temp);
			    $aseqlength = @s1;
			    $bseq_temp = $bseq;
			    $bseq_temp =~ /(\+.*\+)([^+]*)$/;
			    $ins = $1;
			    $bpostfix = $2;
			    $bseq_temp =~ s/(\+.*\+)//;
			    @s2 = split(//,$bseq_temp);
			    $bseqlength = @s2;
			    $merged_seq = $aseq;
			    for($p=$aseqlength+$bseqlength-$merged_length; $p<@s2; $p++) {
				$merged_seq = $merged_seq . $s2[$p]
			    }
			    $str_temp = $ins . $bpostfix;
			    $str_temp =~ s/\+/\\+/g;
			    if(!($merged_seq =~ /$str_temp/)) {
				$merged_seq =~ s/$bpostfix$/$ins$bpostfix/;
			    }
			    $consistent_mappers{"seq.$seq_count\t$achr\t$merged_spans\t$merged_seq"}++;
			}
		    }
		}
	    }
	}


	$max_spans_length = 0;
	foreach $key (keys %consistent_mappers) {
	    @K = split(/\t/,$key);
	    @SS = split(/, /, $K[2]);
	    $sl = 0;
	    for($i=0; $i<@SS; $i++) {
		@SS2 = split(/-/,$SS[$i]);
		$sl = $sl + $SS2[1] - $SS2[0] + 1;
	    }
	    if($sl > $max_spans_length) {
		$max_spans_length = $sl;
	    }
	}

	$num_consistent_mappers=0;
	foreach $key (keys %consistent_mappers) {
	    @K = split(/\t/,$key);
	    @SS = split(/, /, $K[2]);
	    $sl = 0;
	    for($i=0; $i<@SS; $i++) {
		@SS2 = split(/-/,$SS[$i]);
		$sl = $sl + $SS2[1] - $SS2[0] + 1;
	    }
	    if($sl == $max_spans_length) {
		$consistent_mappers2{$key}++;
		$num_consistent_mappers++;
	    }
	}

	if($num_consistent_mappers == 1) {
	    foreach $key (keys %consistent_mappers2) {
		@A = split(/\n/,$key);
		for($n=0; $n<@A; $n++) {
		    @a = split(/\t/,$A[$n]);
		    $seq_new = addJunctionsToSeq($a[3], $a[2]);
		    if(@A == 2 && $n == 0) {
			$outstring = "$a[0]\t$a[1]\t$a[2]\t$seq_new\n";
			print RESULTS $outstring;
		    }
		    if(@A == 2 && $n == 1) {
			$outstring = "$a[0]\t$a[1]\t$a[2]\t$seq_new\n";
			print RESULTS $outstring;
		    }
		    if(@A == 1) {
			print RESULTS "$a[0]\t$a[1]\t$a[2]\t$seq_new\n";
		    }
		}
	    }
	}
	else {
	    $ccnt = 0;
	    $num_absplit = 0;
	    $num_absingle = 0;
	    undef @spans1;
	    undef @spans2;
	    undef %CHRS;
	    foreach $key (keys %consistent_mappers2) {
		@A = split(/\n/,$key);
		@a = split(/\t/,$A[0]);
		$CHRS{$a[1]}++;
		if(@A == 1) {
		    $num_absingle++;
		    $spans1[$ccnt] = $a[2];
		    if($ccnt == 0) {
			$firstseq = $a[3];
		    }
		}
		if(@A == 2) {
		    $num_absplit++;
		    $spans1[$ccnt] = $a[2];
		    if($ccnt == 0) {
			$firstseq1 = $a[3];
		    }
		    @a = split(/\t/,$A[1]);
		    $spans2[$ccnt] = $a[2];
		    if($ccnt == 0) {
			$firstseq2 = $a[3];
		    }
		}
		$ccnt++;
		$key_hold = $key;
	    }
	    $nchrs = 0;
	    foreach $ky (keys %CHRS) {
		$nchrs++;
		$CHR = $ky;
	    }
	    $nointersection = 1;
	    if($num_absingle == 0 && $num_absplit > 0 && $nchrs == 1) {
		$firstseq1 =~ s/://g;
		$firstseq2 =~ s/://g;
		$str1 = intersect(\@spans1, $firstseq1);
		$str2 = intersect(\@spans2, $firstseq2);
		if($str1 ne "0\t" && $str2 eq "0\t") {
		    $str1 =~ s/^(\d+)\t/$CHR\t/;
		    $size1 = $1;
		    if($size1 >= $min_size_intersection_allowed) {
			@ss = split(/\t/,$str1);
			$seq_new = addJunctionsToSeq($ss[2], $ss[1]);
			print RESULTS "seq.$seq_count";
			print RESULTS "a\t$ss[0]\t$ss[1]\t$seq_new\n";
			$nointersection = 0;
		    }
		}
		if($str2 ne "0\t" && $str1 eq "0\t") {
		    $str2 =~ s/^(\d+)\t/$CHR\t/;
		    $size2 = $1;
		    if($size2 >= $min_size_intersection_allowed) {
			@ss = split(/\t/,$str2);
			$seq_new = addJunctionsToSeq($ss[2], $ss[1]);
			print RESULTS "seq.$seq_count";
			print RESULTS "b\t$ss[0]\t$ss[1]\t$seq_new\n";
			$nointersection = 0;
		    }
		}
		if($str1 ne "0\t" && $str2 ne "0\t") {
		    $str1 =~ s/^(\d+)\t/$CHR\t/;
		    $size1 = $1;
		    $str2 =~ s/^(\d+)\t/$CHR\t/;
		    $size2 = $1;
		    if($size1 >= $min_size_intersection_allowed && $size2 < $min_size_intersection_allowed) {
			@ss = split(/\t/,$str1);
			$seq_new = addJunctionsToSeq($ss[2], $ss[1]);
			print RESULTS "seq.$seq_count";
			print RESULTS "a\t$ss[0]\t$ss[1]\t$seq_new\n";
			$nointersection = 0;
		    }
		    if($size2 >= $min_size_intersection_allowed && $size1 < $min_size_intersection_allowed) {
			@ss = split(/\t/,$str2);
			$seq_new = addJunctionsToSeq($ss[2], $ss[1]);
			print RESULTS "seq.$seq_count";
			print RESULTS "b\t$ss[0]\t$ss[1]\t$seq_new\n";
			$nointersection = 0;
		    }
		    if($size1 >= $min_size_intersection_allowed && $size2 >= $min_size_intersection_allowed) {
			$str1 =~ /^[^\t]+\t(\d+)[^\t+]-(\d+)\t/;
			$start1 = $1;
			$end1 = $2;
			$str2 =~ /^[^\t]+\t(\d+)[^\t+]-(\d+)\t/;
			$start2 = $1;
			$end2 = $2;
			if((($start2 - $end1 > 0) && ($start2 - $end1 < $max_distance_between_paired_reads)) || (($start1 - $end2 > 0) && ($start1 - $end2 < $max_distance_between_paired_reads))) {
			    @ss = split(/\t/,$str1);
			    $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
			    print RESULTS "seq.$seq_count";
			    print RESULTS "a\t$ss[0]\t$ss[1]\t$seq_new\n";
			    @ss = split(/\t/,$str2);
			    $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
			    print RESULTS "seq.$seq_count";
			    print RESULTS "b\t$ss[0]\t$ss[1]\t$seq_new\n";
			    $nointersection = 0;
			}
		    }
		}
	    }
	    if($num_absingle > 0 && $num_absplit == 0 && $nchrs == 1) {
		$str = intersect(\@spans1, $firstseq);
		if($str ne "0\t") {
		    $str =~ s/^(\d+)\t/$CHR\t/;
		    $size = $1;
		    if($size >= $min_size_intersection_allowed) {
			@ss = split(/\t/,$str);
			$seq_new = addJunctionsToSeq($ss[2], $ss[1]);
			print RESULTS "seq.$seq_count\t$ss[0]\t$ss[1]\t$seq_new\n";
			$nointersection = 0;
		    }
		}
	    }
	    # NOTE: insertions in non-unique mappers are not being reported.
	    if(($nointersection == 1) || ($nchrs > 1) || ($num_absingle > 0 && $num_absplit > 0)) {
		foreach $key (keys %consistent_mappers2) {
		    @A = split(/\n/,$key);
		    for($n=0; $n<@A; $n++) {
			@a = split(/\t/,$A[$n]);
			$seq_new = addJunctionsToSeq($a[3], $a[2]);
			if(@A == 2 && $n == 0) {
			    print RESULTS2 "$a[0]\t$a[1]\t$a[2]\t$seq_new\n";
			}
			if(@A == 2 && $n == 1) {
			    print RESULTS2 "$a[0]\t$a[1]\t$a[2]\t$seq_new\n";
			}
			if(@A == 1) {
			    print RESULTS2 "$a[0]\t$a[1]\t$a[2]\t$seq_new\n";
			}
		    }
		}
	    }
	}
    }

    undef %consistent_mappers;
    undef %consistent_mappers2;
    undef @read_mapping_to_genome_blatoutput;
    undef %maxlength;
    undef %blathits;
    undef %Ncount;
    undef %cnt;
    undef @one_dir_only_candidate;
    undef @read_mapping_to_genome_coords;
    undef @read_mapping_to_genome_pairing_candidate;
}

close(BLATHITS);
close(RESULTS);
#close(INSERTIONFILE);
    
# seq 12 in s_5 is an intersting marginal case for uniqueness...
# seq 17 hits four exons, but finds only 3 with default BLAT params
# seq.461 example with a ton of short hits

sub getTotalSizeFromBlockSizes () {
    ($blocks) = @_;
    $blocks =~ s/\s*,*\s*$//;
    $blocks =~ s/^\s*,*\s*//;
    @BL = split(/,/, $blocks);
    $totalsize = "";
    for($bl=0; $bl<@BL; $bl++) {
	$totalsize = $totalsize + $BL[$bl];
    }
    return $totalsize;
}

sub getsequence {
    ($blocksizes, $qstarts, $strand, $seq) = @_;
    chomp($seq);
    if($strand eq "-") {
	@a = split(//,$seq);
	$n = @a;
	$revcomp = "";
	for($i=$n-1; $i>=0; $i--) {
	    $flag = 0;
	    if($a[$i] eq 'A') {
		$revcomp = $revcomp . "T";
		$flag = 1;
	    }
	    if($a[$i] eq 'T') {
		$revcomp = $revcomp . "A";
		$flag = 1;
	    }
	    if($a[$i] eq 'C') {
		$revcomp = $revcomp . "G";
		$flag = 1;
	    }
	    if($a[$i] eq 'G') {
		$revcomp = $revcomp . "C";
		$flag = 1;
	    }
	    if($flag == 0) {
		$revcomp = $revcomp . $a[$i];
	    }
	}
	$seq = $revcomp;
    }
    $blocksizes =~ s/,\s*$//;
    $qstarts =~ s/,\s*$//;
    @a = split(/,/,$blocksizes);
    @b = split(/,/,$qstarts);
    @s = split(//,$seq);
    $seq_out = "";
    for($i=0; $i<@a; $i++) {
	for($j=0; $j<$a[$i]; $j++) {
	    $seq_out = $seq_out . "$s[$b[$i]+$j]";
	}
	if($i<@a-1) {
	    if($a[$i]+$b[$i] == $b[$i+1]) {
		$seq_out = $seq_out . ":";
	    }
	    else{
		$seq_out = $seq_out . "+";
		for($k=0; $k<$b[$i+1]-$a[$i]-$b[$i]; $k++) {
		    $seq_out = $seq_out . $s[$b[$i]+$a[$i]+$k];
		}
		$seq_out = $seq_out . "+";
	    }
	}
    }
    return $seq_out;
}

sub intersect () {
    ($spans_ref, $seq) = @_;
    @spans = @{$spans_ref};
    $num = @spans;
    undef %chash;
    for($s=0; $s<$num; $s++) {
	@a = split(/, /,$spans[$s]);
	for($i=0;$i<@a;$i++) {
	    @b = split(/-/,$a[$i]);
	    for($j=$b[0];$j<=$b[1];$j++) {
		$chash{$j}++;
	    }
	}
    }
    $spanlength = 0;
    $flag = 0;
    $maxspanlength = 0;
    $maxspan_start = 0;
    $maxspan_end = 0;
    $prevkey = 0;
    for $key (sort {$a <=> $b} keys %chash) {
	if($chash{$key} == $num) {
	    if($flag == 0) {
		$flag = 1;
		$span_start = $key;
	    }
	    $spanlength++;
	}
	else {
	    if($flag == 1) {
		$flag = 0;
		if($spanlength > $maxspanlength) {
		    $maxspanlength = $spanlength;
		    $maxspan_start = $span_start;
		    $maxspan_end = $prevkey;
		}
		$spanlength = 0;
	    }
	}
	$prevkey = $key;
    }
    if($flag == 1) {
	if($spanlength > $maxspanlength) {
	    $maxspanlength = $spanlength;
	    $maxspan_start = $span_start;
	    $maxspan_end = $prevkey;
	}
    }
    if($maxspanlength > 0) {
	@a = split(/, /,$spans[0]);
	@b = split(/-/,$a[0]);
	$i=0;
	until($b[1] >= $maxspan_start) {
	    $i++;
	    @b = split(/-/,$a[$i]);
	}
	$prefix_size = $maxspan_start - $b[0];  # the size of the part removed from spans[0]
	for($j=0; $j<$i; $j++) {
	    @b = split(/-/,$a[$j]);
	    $prefix_size = $prefix_size + $b[1] - $b[0] + 1;
	}
	@s = split(//,$seq);
	$newseq = "";
	for($i=$prefix_size; $i<$prefix_size + $maxspanlength; $i++) {
	    $newseq = $newseq . $s[$i];
	}
	$flag = 0;
	$i=0;
	@b = split(/-/,$a[0]);
	until($b[1] >= $maxspan_start) {
	    $i++;
	    @b = split(/-/,$a[$i]);
	}
	$newspans = $maxspan_start;
	until($b[1] >= $maxspan_end) {
	    $newspans = $newspans . "-$b[1]";
	    $i++;
	    @b = split(/-/,$a[$i]);
	    $newspans = $newspans . ", $b[0]";
	}
	$newspans = $newspans . "-$maxspan_end";
	$off = "";
	for($i=0; $i<$prefix_size; $i++) {
	    $off = $off . " ";
	}
	return "$maxspanlength\t$newspans\t$newseq";
    }
    else {
	return "0\t";
    }
}

sub addJunctionsToSeq () {
    ($seq, $spans) = @_;
    $seq =~ s/://g;
    @s = split(//,$seq);
    @b = split(/, /,$spans);
    $seq_out = "";
    $place = 0;
    for($j=0; $j<@b; $j++) {
	@c = split(/-/,$b[$j]);
	$len = $c[1] - $c[0] + 1;
	if($seq_out =~ /\S/) { # to avoid putting a colon at the beginning
	    $seq_out = $seq_out . ":";
	}
	for($k=0; $k<$len; $k++) {
	    if($s[$place] eq "+") {
		$seq_out = $seq_out . $s[$place];
		$place++;
		until($s[$place] eq "+") {
		    $seq_out = $seq_out . $s[$place];
		    $place++;
		    if($place > @s-1) {
			last;
		    }
		}
		$k--;
	    }
	    $seq_out = $seq_out . $s[$place];
	    $place++;
	}
    }
    return $seq_out;
}
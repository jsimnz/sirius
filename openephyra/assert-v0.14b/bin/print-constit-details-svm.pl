#!/bin/perl

# modified from Match/score-constit.pl
# in order to accept parses in paren rather than SGML format

# 4/5/2000: compute both P(fe|path) and P(fe|path,t)

# 6/6/2000: print output in format accepted by score-feg-subcat-frame.pl
# in order to do bootstrapping of unseen data
# (remove hashes with stats - using too much memory, not needed when 
# just printing constits)

#---- Notes ----#
# - if the soft option is used and in case the data is already labeled with
#   the frame elements, then the backed-off path will be labeled with the correct
#   frame element that was used to get that statistic, but the frame element will
#   not be correct -- in the sense that it will be the backed off set of words 
#   instead of the entire fe string marked in the training, but it might be
#   good to use this while calculating classification error, as sometimes the 
#   backed-off string would be a correct frame-element, instead of being a  
#   one-word preposition or determiner or something of that kind. It would
#   also be worthwhile to check how many of the backed-off statistics
#   are indeed good statistics and how many are garbage statistics -- ie. the
#   one pointing to a single word or something that does not represent any
#   part of the frame element in some sense
#---------------#

$| = 1;

#---- use conditional probabilities to predict frame elements ----#

$TRUE  = 1;
$FALSE = 0;

$NULL_NON_NULL  = $FALSE;
$ONLY_ROLES     = $FALSE;
$NULL_AND_ROLES = $TRUE;

$TARGET_HEAD_POSN = $FALSE;

$DEBUG = $FALSE;
$VERBOSE = $FALSE;
$GENERALIZE_NE = $FALSE;

$REMOVE_PATH_DIRECTION = $FALSE;
$LEFT_PATH_SEPERATOR   = "<-";
$RIGHT_PATH_SEPERATOR  = "->";

$COMPRESS_PATH_SEQ  = $FALSE;
$COMPRESS_PATH_ENDS = $FALSE;

$USE_HALF_PATH_TO_CONSTITUENT = "FALSE";
$ADD_HALF_PATH_TO_CONSTITUENT = "FALSE";

$NO_BACKOFF             = $TRUE;   #--- default ---#
$BACKOFF                = $FALSE;
$INTERPOLATION          = $FALSE;
$LM_BASED_ESTIMATION    = $FALSE;

$NE = $FALSE;

$ONLY_HEAD = $FALSE;
$ONLY_PATH = $FALSE;


$missed = 0;
$mismatch = 0;

if ( $#ARGV == -1)
{
	print "Usage: print-constit-details.pl [-theta] [-soft] [-debug] [-mapping <mapping-file>] [train-paths] [train-isfe] < [test-file] > [probable-constituents]\n";
	exit;
}

if ($ARGV[0] eq '-theta') 
{
    $theta_opt = shift;
	
}

if ($ARGV[0] eq '-soft') 
{
    $soft_opt = shift;
}

if ($ARGV[0] eq '-debug') 
{
	shift;
    $DEBUG = $TRUE;
}

if ($ARGV[0] eq '-mapping') 
{
	$mapping_opt = shift;
    $mapping_file = shift;
}

if( $ARGV[0] eq '-with-ne' )
{
	shift;
	#print STDERR "-with-ne set\n";
	$NE = $TRUE;
}

if( $ARGV[0] eq '-only-temp-and-loc-ne' )
{
	shift;
	print STDERR "-only-temp-and-loc-ne set\n";
	$ONLY_TEMP_AND_LOC_NE = $TRUE;
}

if( $ARGV[0] eq '-ne-head-always' )
{
	shift;
	print STDERR "-ne-head-always set\n";
	$ne_head_always = $TRUE;
}

if ($ARGV[0] eq '-verbose') 
{
	shift;
    $VERBOSE = $TRUE;
}

if( $ARGV[0] eq '-threshold' )
{
	shift;
	$THRESHOLD = shift;
	#print STDERR "threshold: $THRESHOLD\n";
}
else
{
	#--- default threshold is 0 ---#
	$THRESHOLD = 0.0;
	#print STDERR "threshold: 0.0\n";
}

if( $ARGV[0] eq "-only-path")
{
	shift;
	print STDERR "-only-path set\n";
	$ONLY_PATH = $TRUE;
}

if( $ARGV[0] eq "-only-head")
{
	shift;
	print STDERR "-only-head set\n";
	$ONLY_HEAD = $TRUE;
}

if( $ARGV[0] eq '-generalize-ne' )
{
	shift;
	print STDERR "-generalize-ne set\n";
	$GENERALIZE_NE = $TRUE;
}

if( $ARGV[0] eq '-head-pos' )
{
	shift;
	#print STDERR "=head-pos set\n";
	$HEAD_POS = $TRUE;
}

if ($ARGV[0] eq '-passives-file') 
{
    $passives_file_opt = shift;
	$passives_file = shift;
	print STDERR "passives_file: $passives_file\n";
}

if ($ARGV[0] eq '-old-feature-value-style') 
{
	$old_feature_value_style = $TRUE;
	shift;
	print STDERR "using old feature values for position and voice\n";
}

if( $ARGV[0] eq '-null-non-null' )
{
	shift;
	$NULL_NON_NULL = $TRUE;
	$NULL_AND_ROLES = $FALSE;
}

if( $ARGV[0] eq '-only-roles' )
{
	shift;
	$ONLY_ROLES = $TRUE;
	$NULL_AND_ROLES = $FALSE;
}

if( $ARGV[0] eq '-null-and-roles' )
{
	shift;
	$NULL_AND_ROLES = $TRUE;
	$ONLY_ROLES     = $FALSE;
	$NULL_NON_NULL  = $FALSE;
}

if( $ARGV[0] eq '-target-head-posn' )
{
	shift;
	$TARGET_HEAD_POSN = $TRUE;
}

if ($ARGV[0] eq '-salient-words') 
{
	$salient_words_opt = shift;
    $salient_words_file = shift;
}

#----------------------------------------------------------------------------#
# The passives file option is provided when the test file is not from 
# FrameNet data, and the global passives do not contain the required 
# information
#----------------------------------------------------------------------------#
if( $passives_file_opt )
{
	open(PASS, "$passives_file") || die;
}
else
{
	open(PASS, "$ENV{\"ASSERT\"}/data/passives") || die;
n}
   
while (<PASS>) 
{
    ($tpos) = /=(.*)$/;
    $pass{$tpos}++;
}

#if( $ARGV[0] eq '-head-cluster' )
#{
#	shift;
#	$HEAD_CLUSTER = $TRUE;
#}

if( $ARGV[0] eq '-head-pos-cluster' )
{
	shift;
	print STDERR "-head-pos-cluster set\n";
	$HEAD_POS_CLUSTER = $TRUE;
}

if( $ARGV[0] eq '-compress-path-seq' )
{
	shift;
	$COMPRESS_PATH_SEQ = $TRUE;
}

if( $ARGV[0] eq '-compress-path-ends' )
{
	shift;
	$COMPRESS_PATH_ENDS = $TRUE;
}

if( $ARGV[0] eq '-remove-path-direction' )
{
	shift;
	$REMOVE_PATH_DIRECTION = $TRUE;
	$LEFT_PATH_SEPERATOR   = "-";
	$RIGHT_PATH_SEPERATOR  = "-";
}

if( $ARGV[0] eq '-use-half-path-to-constituent')
{
	shift;
	$USE_HALF_PATH_TO_CONSTITUENT = $TRUE;
}

if( $ARGV[0] eq '-add-half-path-to-constituent')
{
	shift;
	$ADD_HALF_PATH_TO_CONSTITUENT = $TRUE;
}

if( $ARGV[0] eq '-no-backoff')
{
	shift;
	$NO_BACKOFF = $TRUE;
}

if( $ARGV[0] eq '-backoff' )
{
	shift;
	$BACKOFF = $TRUE;
	$NO_BACKOFF = $FALSE;
}

if( $ARGV[0] eq '-interpolated' )
{
	shift;
	$INTERPOLATION = $TRUE;
	$NO_BACKOFF = $FALSE;
}

if( $ARGV[0] eq '-lm-based-estimation' )
{
	shift;
	$LM_BASED_ESTIMATION = $TRUE;
	$NO_BACKOFF = $FALSE;
}

if( $mapping_opt )
{
	open(FD, "$mapping_file") || die;
}
else
{
	open(FD, "$ENV{\"ASSERT\"}/data/mapping-files/key.txt") || die;
}

while (<FD>) 
{
    chop;
    if (/^\t/) 
	{
		($dummy, $fe, $theta, $count) = split(/\t/, $_);
		$fe2theta{$frame}{$fe} = $theta;
    } 
	elsif (/\//) 
	{
		$frame = $_;
		$frame =~ s/^DOMAIN\///g;
    }
}

if( $salient_words_opt )
{
	print STDERR "salient words file: $salient_words_file\n";
	open(SAL, "$salient_words_file") || die;
}
else
{
	open(SAL, "$ENV{\"FRAMENET\"}/Data/salient-words");
}


undef %salient_hash;

while(<SAL>)
{
	chomp;
	if($DEBUG == $TRUE)
	{
		print "adding $_\n";
	}
	$salient_hash{$_}++;
}

open(SEN, ">sentences");
open(HEAD_TAGGED, ">head-tagged-fn-file");
open(HEAD_WORD_MAP, ">head-map-file");

require 'head-tight.pl';
require 'head-chiang.pl';

if( $DEBUG == $FALSE )
{
	#---------------------- now reading cluster information ---------------#
	#---- Read the cluster information ----#
	#---- We will hardcode some cluster information since it will be same for a while, and won't have to be entered for every command ----#

	$verb_cluster_file = "$ENV{\"ASSERT\"}/data/verb-cluster-file";
	$noun_cluster_file = "$ENV{\"ASSERT\"}/data/noun-cluster-file";
		
	# read in verb vocab: verb to numeric ID
	open(V, $verb_cluster_file) || die;
	while (<V>) 
	{
		($v, $vcid) = split;
		$vcid_hash{$v} = $vcid;
	}
	print STDERR "read noun cluster memberships\n";
	
	# read in noun vocab: noun to numeric ID
	open(N, $noun_cluster_file) || die;
	while (<N>) 
	{
		($n, $ncid) = split;
		$ncid_hash{$n} = $ncid;
	}
	print STDERR "read verb cluster memberships\n";
	#---------------------------------------------------------------------#
}

$verb_cluster_undef = 0;
$noun_cluster_undef = 0;
$verb_cluster_def = 0;
$noun_cluster_def = 0;
$other_cluster_undef = 0;

undef $head_verb_cluster_undef;
undef $head_noun_cluster_undef;
undef $head_verb_cluster_def;
undef $head_noun_cluster_def;
undef $head_other_cluster_undef;

undef $head_word_cluster;

while (<>) 
{
    undef @w;
	undef $mx_prob;
	undef $mx_prob_index;
	undef $word;
	undef $word_pos;

    $parse = <>;
	$original_parse = $parse;
		
#    while ($parse =~ s/\(([^ ]*) ([^\)\(]*)\)/<$1> $2 <\/$1>/) {}
#    @parse = split(/[ \t\n]+/, $parse);

    undef %pcons; undef %parent; undef %head; undef %head_pos_hash; undef %head_ind_hash; undef %rule; undef %path;
    undef %highestpath; undef %prob; undef %paths; undef %phrase_head;
	undef %missed_hash;
	
    $i = 0;
    $cid = 0;
	
	if($NE == $TRUE)
	{
		$ne = <>;
		
		
  		if( $DEBUG == $TRUE )
  		{
  			print "parse--: $parse\n";
  			print "$ne\n";
  		}
		
		#--- since the ne tags are attached to the word on both sides, we should separate them before processing the tokens ---#
		$ne =~ s/">/"> /g;
		$ne =~ s/<\// <\//g;
		
		$ne =~ s/ TYPE/-TYPE/g;
		
  		if( $DEBUG == $TRUE )
  		{
  			print "$ne\n";
  		}
		
		@syn_array = split(/[ \t\n]+/, $parse);
		@ne_array  = split(/[ \t\n]+/, $ne);
		
		#print join("\n", @ne_array);
		
		undef $current_syn;
		undef $current_ne;
		$syn_index = 0;
		$ne_index  = 0;
		
		$ne_flag = $FALSE;
		$ne_tag  = "NIL";
		
		if( $ONLY_TEMP_AND_LOC_NE == $TRUE )
		{
			#--- replace words in the ne tag with the respective ne ---#
			for $i (0..$#ne_array)
			{
				#print "$i\n";
				if ( $ne_array[$i] =~ /^<(ENA|TI)MEX-TYPE=\"(LOCATION|DATE|TIME)/ )
				{
					($dummy, $ne_tag) = $ne_array[$i] =~ /<(ENA|TI)MEX-TYPE=\"(.*?)\">/;
					$ne_array[$i] = "";
					if( $DEBUG == $TRUE )
					{
						print "ne_tag: $ne_tag\n";
					}
				}
				elsif ($ne_array[$i] =~ /^<\/(ENA|NU|TI)MEX>/)
				{
					$ne_tag = "NIL";
					$ne_array[$i] = "";
				}
				elsif( $ne_array[$i] =~ /PERSON|ORGANIZATION|MONEY|PERCENT/ )
				{
					$ne_tag = "NIL";
					$ne_array[$i] = "";
				}
				else
				{
					if( $ne_tag ne "NIL" )
					{
						$ne_array[$i] = "ne_$ne_tag";
						
						if( $GENERALIZE_NE == $TRUE )
						{
							#--- generalize all the person and organizations to a pronoun category ---#
							$ne_array[$i] =~ s/ne_TIME/ne_TEMPORAL/g;
							$ne_array[$i] =~ s/ne_DATE/ne_TEMPORAL/g;
						}
					}
				}
			}
		}
		else
		{
			#--- replace words in the ne tag with the respective ne ---#
			for $i (0..$#ne_array)
			{
				#print "$i\n";
				if ( $ne_array[$i] =~ /^<(ENA|NU|TI)MEX/ )
				{
					($dummy, $ne_tag) = $ne_array[$i] =~ /<(ENA|NU|TI)MEX-TYPE=\"(.*?)\">/;
					$ne_array[$i] = "";
					if( $DEBUG == $TRUE )
					{
						print "$ne_tag\n";
					}
				}
				elsif ($ne_array[$i] =~ /^<\/(ENA|NU|TI)MEX>/)
				{
					$ne_tag = "NIL";
					$ne_array[$i] = "";
				}
				else
				{
					if( $ne_tag ne "NIL" )
					{
						#print "\n==> $ne_array[$i]\n";
						$ne_array[$i] = "ne_$ne_tag";
						
						if( $GENERALIZE_NE == $TRUE )
						{
							#--- generalize all the person and organizations to a pronoun category ---#
							$ne_array[$i] =~ s/ne_PERSON/ne_PRONOUN/g;
							$ne_array[$i] =~ s/ne_ORGANIZATION/ne_PRONOUN/g;
							$ne_array[$i] =~ s/ne_TIME/ne_TEMPORAL/g;
							$ne_array[$i] =~ s/ne_DATE/ne_TEMPORAL/g;
						}
					}
				}
			}
		}
		

		$ne_sentence = join(" ", @ne_array);
		$ne_sentence =~ s/\s+/ /g;
		$ne_sentence =~ s/^\s+//g;
		$ne_sentence =~ s/\s+$//g;
		
		#print "$ne_sentence\n";
		#print "$parse\n";

		@ne_array = split("[ \t\n]", $ne_sentence);
	}

	#--- replace all the opening and closing braces in parse with corresponding opening and closing tags ---#
	while ($parse =~ s/\(([^ ]*) ([^\)\(]*)\)/<$1> $2 <\/$1>/) {}
	
	$parse =~ s/  */ /g;

	@orig_words = split("[ \t\n]+", $parse);

  	if ( $DEBUG == $TRUE )
  	{
  		print "SGML tagged parse: $parse\n";
  		if($NE == $TRUE)
  		{
  			print "NE tagged sentence: $ne_sentence\n";
  		}
  	}

undef @n_some_array;
undef @n_head_tagged_some_array;

	if($NE == $TRUE)
	{
		for $n_i (0..$#orig_words)
		{
			if( $orig_words[$n_i] =~ /</ )
			{
			}
			else
			{
				push(@n_some_array, $orig_words[$n_i]);
				push(@n_head_tagged_some_array, $orig_words[$n_i]);
			}
		}
		
		if( $DEBUG == $TRUE )
		{
			print "ORIG WORD ARRAY: ";
			print join(" ", @n_some_array);
			print join(" ", @n_head_tagged_some_array);
			print "\n";
		}
	}



undef @n_hpos_some_array;

	if($NE == $TRUE)
	{
		for $n_i (0..$#orig_words)
		{
			if( $orig_words[$n_i] =~ /</ )
			{
			}
			else
			{
				$some_word = $orig_words[$n_i+1];
				$some_word =~ s/<\///g;
				$some_word =~ s/>//g;

				push(@n_hpos_some_array, $some_word);
			}
		}

		if( $DEBUG == $TRUE )
		{
			print "HPOS ARRAY: ";
			print join(" ", @n_hpos_some_array);
			print "\n";
		}
	}

	if($NE == $TRUE)
	{
#Last month LOCATION was ordered to pay MONEY compensation to an elderly woman who was robbed by a 14-year-old boy in care
#
#<S1> <S> <NP> <JJ> Last </JJ> <NN> month </NN> </NP> <NP> <NNP> Wakefield </NNP> </NP> <VP> <AUX> was </AUX> <VP> <VBN> ordered </VBN> <S> <VP> <TO> to </TO> <VP> <VB> pay </VB> <NP> <CD> ,000 </CD> <NN> compensation </NN> </NP> <PP> <TO> to </TO> <NP> <NP> <DT> an </DT> <JJ> elderly </JJ> <NN> woman </NN> </NP> <SBAR> <WHNP> <WP> who </WP> </WHNP> <S> <VP> <AUX> was </AUX> <VP> <VBN> robbed </VBN> <PP> <IN> by </IN> <NP> <NP> <DT> a </DT> <JJ> 14-year-old </JJ> <NN> boy </NN> </NP> <PP> <IN> in </IN> <NP> <NN> care </NN> </NP> </PP> </NP> </PP> </VP> </VP> </S> </SBAR> </NP> </PP> </VP> </VP> </S> </VP> </VP> </S> </S1>
		
		#open(out_1, ">>1");
		#open(out_2, ">>2");
		
		if( $parse =~ /></ )
		{
			print STDERR "ERROR: Found a )( in the parse\n";
			print $_;
			exit;
		}
		
		@syn_array = split("[ \t\n]", $parse);
		$syn_index = 0;
		
		$temp = join("\n", @syn_array);
		#print out_1 $temp;
		
		for $i (0..$#ne_array)
		{
			while($syn_array[$syn_index] =~ /^<(\/)?[^>][^>]*>/)
			{
				$syn_index++;
			}
			
			if( $syn_array[$syn_index] ne $ne_array[$i] )
			{
				$syn_array[$syn_index] = $ne_array[$i];
			}
			
			if( $GENERALIZE_NE == $TRUE && $ONLY_TEMP_AND_LOC_NE == $FALSE )
			{
				$syn_array[$syn_index] =~ s/\b(he|him|his|himself|she|her|herself|you|your|they|them|their|themselves|this|that|we|us|our|i|me|my|mine|it|its)\b/ne_PRONOUN/gi;
			}
			$syn_index++;
		}
		
  		if( $DEBUG == $TRUE )
  		{
			print "SYN ARRAY: ";
  			print join(" ", @syn_array);
  			print "\n";
  		}
		
		$parse = join("\n", @syn_array);
		#print out_2 $parse;
		
		#---- end code for inserting the nes in the parse ----#
	}

	#--- create an array of all the tags and words ---#
    @parse = split(/[ \t\n]+/, $parse);

	if ($DEBUG)
	{
		foreach $parse (@parse)
		{
			print "parse element: $parse\n";
		}
	}


    $sep = <>;
    print STDERR "EXPECTED NEWLINE\n" unless $sep =~ /^$/;
	
    ($frame, $target) = /^DOMAIN\/([^:]*)\/([^\/:]*):/;
	($prefix) = /^(DOMAIN.*?>)/;
	#print "$frame\t$target\n";
	#print "$prefix\n";
	#exit;

    $target =~ s/\.ar$//;
    ($tpos) = /TPOS=\"(.*?)\"/;

	#---------------- getting cluster membership information --------------------#
	$word = $target;

	#--- first we do have to check whether it is a verb/noun or something else ---#
	if( $word =~ s/\.v// )
	{
		
		$word =~ s/\.[^.][^.]*$//g;

		#--- the target is a verb ---#
		$word_pos = "verb";
		if( defined $vcid_hash{$word} )
		{
			$mx_prob_index = $vcid_hash{$word};
			$verb_cluster_def++;
		}
		else
		{
			#--- we do not have any cluster information on it ---#
			$mx_prob_index = "undefined";
			$verb_cluster_undef++;
		}
	}
	elsif( $word =~ s/\.n// )
	{
		$word =~ s/\.[^.][^.]*$//g;

		$word_pos = "noun";
		#--- the target is a verb ---#
		if( defined $ncid_hash{$word} )
		{
			$mx_prob_index = $ncid_hash{$word};
			$noun_cluster_def++;
		}
		else
		{
			#--- we do not have any cluster information on it ---#
			$mx_prob_index = "undefined";
			$noun_cluster_undef++;
		}
	}
	else
	{
		#--- we do not have any cluster information on it ---#
		$word_pos = "other";
		$mx_prob_index = "undefined";
		$other_cluster_undef++;
	}

	#print "word $word belongs to $word_pos-cluster-$mx_prob_index\n";
	#--- end finding cluster membership information -----------------------------#

#    next unless ($target =~ /\.v$/);
	
	#--- standard preprocessing ---#
    s/^[^:]*://;
    s/<\/?S[^>]*>//g;
    s/<\/?T[^>]*>//g;
    s/ *//;
	
    while (s/<([^ >]+) /<$1-/g) {}
	
#    print;
#    ($target) = /TARGET=\"y\">([^ \"]*)<\/C>/;
#    $target = lc($target);

	$iii=0 ;
    for $w (@parse) 
	{
		if ($w =~ /^<\//) #--- at the end of the parse sub tree or something...
		{
			undef $rule;
			undef @rhh;
			undef @rhh_ind;

			while ($c = pop(@stack)) 
			{
				if( $DEBUG == $TRUE )
				{
					print "c: $c\n";
				}
				
				if ($c =~ /^</) 
				{
					last;
				} 
				else 
				{
					$rule = $rule ? "$c-$rule" : $c;
					unshift(@rhh, pop(@hw));
					unshift(@rhh_ind, pop(@ind_hw));
				}
			}
			
			$c =~ s/^<//;
			$c =~ s/>$//;

			if( $DEBUG == $TRUE )
			{
				print "rhh: @rhh\n";
				print "rhh_ind: @rhh_ind\n";
				print "rule: $rule\n";
			}

			if ($rule) 
			{
				$temp = join(" ", @rhh);
				@cons_list = split("-", $rule);
				#print "$temp\n";

				if( $ONLY_TEMP_AND_LOC_NE == $TRUE )
				{
					if( $temp =~ /ne_(L|T|D|l|t|d)/ and $ne_head_always == $TRUE )
					{
						@something = ( $temp =~ /(ne_[a-zA-Z][a-zA-Z]*)/g );
						#print "something: ", $something, "\n";
						#print join("\n", @something), "\n";
						$head = $something[0];
					}
					else
					{
						if (!defined $headpos{"$c->$rule"})
						{                                                                                                                     
							$headpos{"$c->$rule"} = &head_pos($c, split(/-/, $rule));
						}
						
						#print "joined: ", join(" ", @rhh), "\n";
						#print $rule;
						$rule = "$c->$rule";
						$head = $rhh[$headpos{$rule}];
						$head_ind = $rhh_ind[$headpos{$rule}];
						$head_word_pos = $cons_list[$headpos{$rule}];
						}
					#print "head: $head\n";
				}
				else
				{
					if( $temp =~ /ne_/ and $ne_head_always == $TRUE )
					{
						@something = ( $temp =~ /(ne_[a-z][a-z]*)/g );
						#print "something: ", $something, "\n";
						#print join("\n", @something), "\n";
						$head = $something[0];
					}
					else
					{
						if (!defined $headpos{"$c->$rule"})
						{                                                                                                                     
							$headpos{"$c->$rule"} = &head_pos($c, split(/-/, $rule));
						}
						
						#print "joined: ", join(" ", @rhh), "\n";
						#print $rule;
						$rule = "$c->$rule";
						$head = $rhh[$headpos{$rule}];
						$head_ind = $rhh_ind[$headpos{$rule}];
						$head_word_pos = $cons_list[$headpos{$rule}];
						
					}
					#print "head: $head\n";
				}
			} 
			else #--- this means that is the only word in the constituent i guess
			{
				# if $head is a named entity. then
				# that is the head
				# this should not be required as we 
				# have already replaced the words
				# with named entities
				#print "came here\n";
				if( $DEBUG == $TRUE )
				{
					print "\@hw: @hw\n";
					print "\@ind_hw: @ind_hw\n";
					#print "head: $head\n";
				}

				$head = pop(@hw);
				$head_word_pos = $c;
				$head_ind = pop(@ind_hw);
			}

			#print "head: $head\n";
			$j = pop(@numstack);
			$nt = pop(@ntstack);
			
			undef $p;
			$k = $#ntstack;

			if ($c eq NP)
			{
				while ($k >= 0) 
				{
					if ($ntstack[$k] =~ /^<S/ || $ntstack[$k] =~ /^<V/) 
					{
						$p = $ntstack[$k];
						last;
					}
					$k--;
				}
			}

#   	    $p = $ntstack[$#ntstack];
			
			
			$path = "$head " . join(' ', @ntstack, $nt);
			$path{$j}{$i-1} = $path unless $path{$j}{$i-1};
			$highestpath{$j}{$i-1} = $path;

			if( $DEBUG == $TRUE )
			{
				print "highestpath: $highestpath{$j}{$i-1}\n";
			}
				@highestpath_phrase_list = split(" ", $highestpath{$j}{$i-1});
				$phrase_head{$highestpath_phrase_list[$#highestpath_phrase_list]} = $highestpath_phrase_list[0];

			if( $DEBUG == $TRUE )
			{
				print "last phrase: $highestpath_phrase_list[$#highestpath_phrase_list]\n";
				print "head word  : $phrase_head{$highestpath_phrase_list[$#highestpath_phrase_list]}\n";
				print "head word pos: $head_word_pos\n";
				print "head word index: $head_ind\n";
			}

			$paths{$path}++;
			$pcons{$j}{$i-1} = $c;
			$head{$j}{$i-1} = $head;
			$head_pos_hash{$j}{$i-1} = $head_word_pos;
			$head_ind_hash{$j}{$i-1} = $head_ind;
			$parent{$j}{$i-1} = $p;
			$rule{$nt} = $rule;
			
			push(@stack, $c);
			push(@hw, $head);
			push(@ind_hw, $head_ind);
			
			# undef $nearesthyper;
			
			# WordNet hypernyms
#   	    ($pos) = $c =~ /^(.)/;
#	        if ($pos =~ /^[NV]/) 
#			{
#    		    $pos = lc($pos);
##		        print "SynsetNumbersNew $head, $pos\n";
#		        @senses = &SynsetNumbersNew($head, $pos);
#		        if ($#senses >= 0) 
#               {
#		            # only using first sense returned
##		            print " GetAllHyps $senses[0], $pos\n";
#		            @hyper = &GetAllHyps($senses[$#senses], $pos);
#		            for $hyper (@hyper) 
#                   {
##			            print " $head $hyper\n";
#			            if ($t_wn_total{$target}{$pos.$hyper}) 
#                       {
#           			    $nearesthyper{$j}{$i-1} = $hyper;
#			                $nearesthyper = $hyper;
#           			    print "  $head $hyper $pos $target $t_wn_total{$target}{$pos.$hyper} ", join(' ', &SynsetWordList($hyper, $pos)), "\n";
#           			    last;
#			            }
#       		    }
#		        }
#	        }
			
			if ("</$c>" ne $w) 
			{
				print STDERR "CONSTITUENT MISMATCH: $c $w $i\n";
			}
		} 
		elsif ($w =~ /^</) 
		{
			push(@stack, $w);
			push(@ntstack, "$w-".$cid++);
			push(@numstack, $i);
		} 
		else 
		{
			$ww = $orig_words[$iii];
			$w[$i] = $w;
			#print "=======>$ww====$w\n";
			#push(@hw, lc($w));
			push(@hw, lc($ww));
			push(@ind_hw, $i);
			$i++;
		}
	   
		$iii++;
    }

    pop(@stack);
    pop(@hw);
	pop(@ind_hw);
	
	
    @a = split;
    undef %cons;
    undef $targetpos;
    $i = 0;
    for $w (@a) 
	{
		if ($w =~ /^<C-([^>]*)>/) 
		{
			push(@stack, $1);
			push(@numstack, $i);
		}
		if ($w =~ /^<[^>]*><[^>]*>$/) 
		{
			$j = -1;
		} 
		elsif ($w =~ /^<[^>]*>$/) 
		{
			$j = $i - 1;
		} 
		else 
		{
			$j = $i;
			$i++;
		}
		
		if ($w =~ /<\/C>$/) 
		{
			$c = pop(@stack);
			if ($c =~ /TARGET=\"y\"/) 
			{
				$targetpos = $j;
				$n_head_tagged_some_array[$targetpos] = "<C TARGET=\"y\"> ".$n_head_tagged_some_array[$targetpos]." </C>";
			} 
			else 
			{
				$cons{pop(@numstack)}{$j} = $c;
			}
		}
    }

    undef %is_fe;

    for $i (sort keys %cons) 
	{
		# this is designed to handle nested constituents even though
		# i don't think they occur
		for $j (sort keys %{$cons{$i}}) 
		{
			($fe) = $cons{$i}{$j} =~ /FE=\"([^\"]*)\"/;
			next unless $fe;
			next if $j < $i;
			
			if($theta_opt)
			{
				#print "'$fe'\t";
				$fe = $fe2theta{$frame}{$fe};
				#print "$'fe'\n";
			}

			# find a valid parse constit in case the frame element is subsumed by some
			# parse constituent.
			if ($soft_opt) 
			{
				if (!$pcons{$i}{$j}) 
				{
					while (!$pcons{$i}{$j}) 
					{ 
						$j--; 
						if ($j < 0) 
						{ 
							print STDERR "\n"; last; 
						}
					}
				}
			}		
			else
			{
				if(!$pcons{$i}{$j})
				{
					if( !($ONLY_ROLES == $TRUE && $is_fe eq "O") ) 
					{
						if($TARGET_HEAD_POSN == $TRUE)
						{
							$missed_hash{$i}{$j} = "$tpos $targetpos"."_X"." $i $j U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U $fe\n";
						}
						else
						{
							$missed_hash{$i}{$j} = "$tpos $targetpos $i $j U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U U $fe\n";
						}
						
						$SOME_FEATURES_PRINTED = $TRUE;
					}

					$mismatch++;
				}
			}

			$sub = join(' ', @w[$i..$j]);
			$is_fe{$highestpath{$i}{$j}} = $fe;
		}
    }


	undef @i_array;
	undef @j_array;

    for $i (sort {$a <=> $b} keys %highestpath) 
	{
		for $j (sort {$a <=> $b} keys %{$highestpath{$i}}) 
		{

			$sub = join(' ', @w[$i..$j]);
			$a = $highestpath{$i}{$j};
			$is_fe = $is_fe{$a};
			$b = $path{$targetpos}{$targetpos};
			
			undef $parent;

			@a = split(/ /, $a);
			@b = split(/ /, $b);

			shift(@b);         # head word of target
			$head = shift(@a); # head word of constit
			$subcat = $rule{$b[$#b-1]};

			while (@a && $a[0] && $a[0] eq $b[0]) 
			{
				# remove common substring of constituents in path from root
				$parent = shift(@a);
				shift(@b);
			}

			$parent =~ s/^<//;
			$parent =~ s/>-\d+//;
			$parent_string = $parent;
			
			@temp = split("", $parent);
			#$one_char_parent_string = "$temp[0]$temp[1]";
			$one_char_parent_string = "$temp[0]";
			map { s/^<//; s/>-\d+//; } @a;
			map { s/^<//; s/>-\d+//; } @b;

			#--- start code for compressing path seq and ends ---#
			if( $DEBUG == $TRUE )
			{
				print "lhs before uniq: '", join($LEFT_PATH_SEPERATOR, reverse(@a)), "'\n";
			}
			
			
			if( $COMPRESS_PATH_SEQ == $TRUE )
			{
				$prev = "not equal to $a[0]";
				@a_out = grep($_ ne $prev && ($prev = $_, 1), @a);
			}
			else
			{
				@a_out = @a;
			}
			
			if( $COMPRESS_PATH_ENDS == $TRUE )
			{
				$popped_element = pop(@a_out);
				#print "popped: $popped_element\n";
			}
			
			$a = join($LEFT_PATH_SEPERATOR, reverse(@a_out));

			@one_char_a = reverse(@a_out);

			for $i ( 0..$#one_char_a )
			{
				@temp = split("", $one_char_a[$i]);
				#$one_char_a[$i] = "$temp[0]$temp[1]";
				$one_char_a[$i] = "$temp[0]";
			}

			$one_char_aa = join($LEFT_PATH_SEPERATOR, @one_char_a);

			#print join(" ", @a_out), "\n";
			#print join(" ", @one_char_a), "\n";
			#exit;

			if( $DEBUG == $TRUE )
			{
				print "lhs after uniq: '", join($LEFT_PATH_SEPERATOR, reverse(@a_out)), "'\n";		
				print "rhs before uniq: '", join($RIGHT_PATH_SEPERATOR, @b), "'\n";
			}
			
			if( $COMPRESS_PATH_SEQ == $TRUE )
			{
				$prev = "not equal to $b[0]";
				@b_out = grep($_ ne $prev && ($prev = $_, 1), @b);
			}
			else
			{
				@b_out = @b;
			}
			
			if( $COMPRESS_PATH_ENDS == $TRUE )
			{
				$popped_element = pop(@b_out);
				#print "popped: $popped_element\n";
			}

			$b = join($RIGHT_PATH_SEPERATOR, @b_out);
			
			@one_char_b = @b_out;

			for $i ( 0..$#one_char_b )
			{
				@temp = split("", $one_char_b[$i]);
				#$one_char_b[$i] = "$temp[0]$temp[1]";
				$one_char_b[$i] = "$temp[0]";
			}
			$one_char_bb = join($RIGHT_PATH_SEPERATOR, @one_char_b);

			#print join(" ", @b_out), "\n";
			#print join(" ", @one_char_b), "\n";
			#exit;

			if( $DEBUG == $TRUE )
			{
				print "rhs after uniq: '", join($RIGHT_PATH_SEPERATOR, @b_out), "'\n";
			}
			
			@a = @a_out;

			if( $USE_HALF_PATH_TO_CONSTITUENT == $TRUE )
			{
				@b = ();
			}
			else
			{
				@b = @b_out;
			}
			
			#----------------------------------------------------#
			#--- now construct the path from the target element to the encompassing non-terminal of the frame element ---#
			if( $#a != -1 && $#b != -1)
			{
				##print "lhs: '$a'\n";
				##print "rhs: '$b'\n";
				$path = "$a$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$b";
				$one_char_path = "$one_char_aa$LEFT_PATH_SEPERATOR$one_char_parent_string$RIGHT_PATH_SEPERATOR$one_char_bb";
				$left_path_string = "$a";
				$right_path_string = "$b";
			}
			elsif( $#a == -1 && $#b != -1 )
			{
				$path = "$parent$RIGHT_PATH_SEPERATOR$b";
				$one_char_path = "$one_char_parent_string$RIGHT_PATH_SEPERATOR$one_char_bb";
				$left_path_string = "U";
				$right_path_string = "$b";
				##print "path: $path\n";
			}
			elsif( $#b == -1  && $#a != -1)
			{
				$path = "$a$LEFT_PATH_SEPERATOR$parent";
				$one_char_path = "$one_char_aa$LEFT_PATH_SEPERATOR$one_char_parent_string";
				$left_path_string = "$a";
				$right_path_string = "U";
			}	
			elsif( $#a == -1 && $#b == -1 )
			{
				$path = "$parent";
				$one_char_path = "$one_char_parent_string";
				$left_path_string = "U";
				$right_path_string = "U";
			}
			
			if( $DEBUG == $TRUE )
			{
				print "path: $path\n";
			}
			
			if( $ADD_HALF_PATH_TO_CONSTITUENT == $TRUE )
			{
				if( $#a != -1 )
				{
					$half_path = "$a$LEFT_PATH_SEPERATOR$parent";
				}
				else
				{
					$half_path = "$parent";
				}
			}

#  			$a = join('<-', reverse(@a));
#  			$b = join('->', @b);			
#  			$path = "$a<-$parent->$b";

			$c = $a[$#a];
			
			#---- skip constituents that are ancestors of target ----#
			next unless $a;      

			push(@i_array, $i);
			push(@j_array, $j);
			#print "$i ";
			#print "$j ";
		}
	}

	#printf "-->start: %s\n", join(" ", @i_array);
	#printf "-->end  : %s\n", join(" ", @j_array);
				
	$SOME_FEATURES_PRINTED = $FALSE;

    for $i (sort {$a <=> $b} keys %highestpath) 
	{
		for $j (sort {$a <=> $b} keys %{$highestpath{$i}}) 
		{
			$missed_hash_break_flag = $FALSE;
			for $i_dash (sort {$a <=> $b} keys %missed_hash) 
			{
				for $j_dash (sort {$a <=> $b} keys %{$missed_hash{$i_dash}}) 
				{

					if( ($i > $i_dash ) || ($i == $i_dash && $j > $j_dash)  )
					{
						print STDERR "$tpos $i $j $i_dash $j_dash\n";
						print $missed_hash{$i_dash}{$j_dash};
						delete $missed_hash{$i_dash}{$j_dash};
						delete $missed_hash{$i_dash};
						$missed_hash_break_flag = $TRUE;
						last;
					}
				}
				if( $missed_hash_break_flag == $TRUE )
				{
					last;
				}
			}
			
			undef %ne_hash;

			$sub = join(' ', @w[$i..$j]);
			$a = $highestpath{$i}{$j};
			if( $DEBUG == $TRUE )
			{
				print "====> $a\n";
			}

			$is_fe = $is_fe{$a};
			$b = $path{$targetpos}{$targetpos};

			#print STDERR "$a\n";
			#print STDERR "$b\n";
			$temp2 = $b;
			$temp2 =~ s/^.*(<S.*?>-[0-9]+).*$/\1/g;
			#print STDERR "temp2: $temp2\n";

			$temp1 = $a;
			#print STDERR "temp1: $temp1\n";

			if( $temp1 =~ /$temp2/ )
			{
				#print STDERR "clause: inside\n";
				$clause = "i";
			}
			else
			{
				#print STDERR "clause: outside\n";
				$clause = "o";
			}

			undef $parent;

			@a = split(/ /, $a);
			@b = split(/ /, $b);

			shift(@b);         # head word of target
			$head = shift(@a); # head word of constit
			$subcat = $rule{$b[$#b-1]};

			while (@a && $a[0] && $a[0] eq $b[0]) 
			{
				# remove common substring of constituents in path from root
				$parent = shift(@a);
				shift(@b);
			}

			$lex_parent = "$parent-$phrase_head{$parent}";
			$lex_parent =~ s/-[0-9]+-/-/g;
			$lex_parent =~ s/>//g;
			$lex_parent =~ s/<//g;

			if( $DEBUG == $TRUE )
			{
				print "lexicalized parent: $lex_parent\n";
			}

			$parent =~ s/^<//;
			$parent =~ s/>-\d+//;
			$parent_string = $parent;

			if( $parent_string eq "" )
			{
				$parent_string = "U";
			}

			@temp = split("", $parent);
			#$one_char_parent_string = "$temp[0]$temp[1]";
			$one_char_parent_string = "$temp[0]";
			

			undef @lex_a; undef @lex_b;
			#print "------\n";
			for $a ( @a )
			{
				#print "$a\n";
				$a_phrase_head = "$a-$phrase_head{$a}";
				$a_phrase_head =~ s/-[0-9]+-/-/g;
				$a_phrase_head =~ s/>//g;
				$a_phrase_head =~ s/<//g;
				#print "$a_phrase_head\n";
				push(@lex_a, $a_phrase_head);
			}
			
			for $b ( @b )
			{
				#print "$b\n";
				$b_phrase_head = "$b-$phrase_head{$b}";
				$b_phrase_head =~ s/-[0-9]+-/-/g;
				$b_phrase_head =~ s/>//g;
				$b_phrase_head =~ s/<//g;
				#print "$b_phrase_head\n";
				push(@lex_b, $b_phrase_head);
			}
			#print "------\n";
			
			if( $DEBUG == $TRUE )
			{
				print "======\n";
				for $a ( @lex_a )
				{
					print "$a\n";
				}
				
				for $b ( @lex_b )
				{
					print "$b\n";
				}
				print "======\n";
			}
			
			map { s/^<//; s/>-\d+//; } @a;
			map { s/^<//; s/>-\d+//; } @b;



			undef $path_clause_flag;
			$path_clause_flag = $FALSE;

			#-------#
			if( $parent_string =~ /^S/ )
			{
				$parent_clause_string = $parent_string;
				$path_clause_flag = $TRUE;
			}
			else
			{
				$parent_clause_string = "";
			}

			if( $parent_string =~ /^S/ )
			{
				$parent_clause_other_asterix_string = $parent_string;
			}
			else
			{
				$parent_clause_other_asterix_string = "*";
			}

			#--- start code for compressing path seq and ends ---#
			if( $DEBUG == $TRUE )
			{
				print "lhs before uniq: '", join($LEFT_PATH_SEPERATOR, reverse(@a)), "'\n";
			}
			
			
			if( $COMPRESS_PATH_SEQ == $TRUE )
			{
				$prev = "not equal to $a[0]";
				@a_out = grep($_ ne $prev && ($prev = $_, 1), @a);
			}
			else
			{
				@a_out = @a;
			}
			
			if( $COMPRESS_PATH_ENDS == $TRUE )
			{
				$popped_element = pop(@a_out);
				#print "popped: $popped_element\n";
			}
			

			@path_left_context_list = @a_out;
			
			for $i (0..7)
			{
				push(@path_left_context_list, "U");
			}

			$path_left_context_string = join(" ", @path_left_context_list[0..4]);

			undef @path_center_left_n_grams;
			for $i (0..5)
			{
				undef @temp;
				push(@temp, $path_left_context_list[$i]);
				push(@temp, $path_left_context_list[$i+1]);
				push(@temp, $path_left_context_list[$i+2]);
				push(@path_center_left_n_grams,join("-", @temp));
			}
			
			#print join(" ", @a_out), "\n";
			#print join(" ", @path_center_left_n_grams), "\n";
			#exit;
			$path_center_left_n_grams_string = join(" ", @path_center_left_n_grams);

			undef @path_only_clause_left_list;

			for $element ( @a_out )
			{
				if( $element =~ /^S/ )
				{
					push(@path_only_clause_left_list, $element);
				}
			}
			
			$path_only_clause_left_string = join($LEFT_PATH_SEPERATOR, reverse(@path_only_clause_left_list));
			#print $path_only_clause_left_string, "\n";

			undef @path_clause_other_asterix_left_list;
			
			for $element ( @a_out )
			{
				if( $element =~ /^S/ )
				{
					push(@path_clause_other_asterix_left_list, $element);
					$path_clause_flag = $TRUE;
				}
				else
				{
					push(@path_clause_other_asterix_left_list, "*");
				}
			}
			
			$path_clause_other_asterix_left_string = join($LEFT_PATH_SEPERATOR, reverse(@path_clause_other_asterix_left_list));

			$a = join($LEFT_PATH_SEPERATOR, reverse(@a_out));
			$lex_a = join($LEFT_PATH_SEPERATOR, reverse(@lex_a));

			@one_char_a = reverse(@a_out);

			for $i ( 0..$#one_char_a )
			{
				@temp = split("", $one_char_a[$i]);
				#$one_char_a[$i] = "$temp[0]$temp[1]";
				$one_char_a[$i] = "$temp[0]";
			}

			$one_char_aa = join($LEFT_PATH_SEPERATOR, @one_char_a);

			if( $DEBUG == $TRUE )
			{
				print "lhs after uniq: '", join($LEFT_PATH_SEPERATOR, reverse(@a_out)), "'\n";		
				print "rhs before uniq: '", join($RIGHT_PATH_SEPERATOR, @b), "'\n";
			}
			
			if( $COMPRESS_PATH_SEQ == $TRUE )
			{
				$prev = "not equal to $b[0]";
				@b_out = grep($_ ne $prev && ($prev = $_, 1), @b);
			}
			else
			{
				@b_out = @b;
			}
			
			if( $COMPRESS_PATH_ENDS == $TRUE )
			{
				$popped_element = pop(@b_out);
				#print "popped: $popped_element\n";
			}

			@path_right_context_list = @b_out;
			
			for $i (0..7)
			{
				push(@path_right_context_list, "U");
			}

			$path_right_context_string = join(" ", @path_right_context_list[0..4]);
			if( $DEBUG == $TRUE )
			{
				print $path_right_context_string, "\n";
			}
			#exit;

			undef @path_center_right_n_grams;
			for $i (0..5)
			{
				undef @temp;
				push(@temp, $path_right_context_list[$i]);
				push(@temp, $path_right_context_list[$i+1]);
				push(@temp, $path_right_context_list[$i+2]);
				push(@path_center_right_n_grams,join("-", @temp));
			}
			
			#print join(" ", @b_out), "\n";
			#print join(" ", @path_center_right_n_grams), "\n";
			$path_center_right_n_grams_string = join(" ", @path_center_right_n_grams);
			#exit;

			undef @path_only_clause_right_list;

			for $element ( @b_out )
			{
				if( $element =~ /^S/ )
				{
					push(@path_only_clause_right_list, $element);
				}
			}
			
			$path_only_clause_right_string = join($RIGHT_PATH_SEPERATOR, @path_only_clause_right_list);
			#print $path_only_clause_right_string, "\n";
			#exit;

			undef @path_clause_other_asterix_right_list;
			
			for $element ( @b_out )
			{
				if( $element =~ /^S/ )
				{
					push(@path_clause_other_asterix_right_list, $element);
					$path_clause_flag = $TRUE;
				}
				else
				{
					push(@path_clause_other_asterix_right_list, "*");
				}
			}
			
			$path_clause_other_asterix_right_string = join($RIGHT_PATH_SEPERATOR, @path_clause_other_asterix_right_list);

			$b = join($RIGHT_PATH_SEPERATOR, @b_out);
			$lex_b = join($RIGHT_PATH_SEPERATOR, @lex_b);
			
			@one_char_b = @b_out;

			for $i ( 0..$#one_char_b )
			{
				@temp = split("", $one_char_b[$i]);
				#$one_char_b[$i] = "$temp[0]$temp[1]";
				$one_char_b[$i] = "$temp[0]";
			}

			$one_char_bb = join($RIGHT_PATH_SEPERATOR, @one_char_b);

			if( $DEBUG == $TRUE )
			{
				print "rhs after uniq: '", join($RIGHT_PATH_SEPERATOR, @b_out), "'\n";
			}
			
			@a = @a_out;

			if( $USE_HALF_PATH_TO_CONSTITUENT == $TRUE )
			{
				@b = ();
			}
			else
			{
				@b = @b_out;
			}
			
			#----------------------------------------------------#
			#--- now construct the path from the target element to the encompassing non-terminal of the frame element ---#
			if( $#a != -1 && $#b != -1)
			{
				##print "lhs: '$a'\n";
				##print "rhs: '$b'\n";
				$path = "$a$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$b";
				$lex_path = "$lex_a$LEFT_PATH_SEPERATOR$lex_parent$RIGHT_PATH_SEPERATOR$lex_b";

				$one_char_path = "$one_char_aa$LEFT_PATH_SEPERATOR$one_char_parent_string$RIGHT_PATH_SEPERATOR$one_char_bb";
				$left_path_string = "$a";
				$right_path_string = "$b";
			}
			elsif( $#a == -1 && $#b != -1 )
			{
				$path = "$parent$RIGHT_PATH_SEPERATOR$b";
				$lex_path = "$lex_parent$RIGHT_PATH_SEPERATOR$lex_b";
				
				$one_char_path = "$one_char_parent_string$RIGHT_PATH_SEPERATOR$one_char_bb";
				$left_path_string = "U";
				$right_path_string = "$b";
				##print "path: $path\n";
			}
			elsif( $#b == -1  && $#a != -1)
			{
				$path = "$a$LEFT_PATH_SEPERATOR$parent";
				$lex_path = "$lex_a$LEFT_PATH_SEPERATOR$lex_parent";

				$one_char_path = "$one_char_aa$LEFT_PATH_SEPERATOR$one_char_parent_string";
				$left_path_string = "$a";
				$right_path_string = "U";
			}	
			elsif( $#a == -1 && $#b == -1 )
			{
				$path = "$parent";
				$lex_path = "$lex_parent";

				$one_char_path = "$one_char_parent_string";
				$left_path_string = "U";
				$right_path_string = "U";
			}
			
			if( $DEBUG == $TRUE )
			{
				print "path: $path\n";
			}

			if( $ADD_HALF_PATH_TO_CONSTITUENT == $TRUE )
			{
				if( $#a != -1 )
				{
					$half_path = "$a$LEFT_PATH_SEPERATOR$parent";
				}
				else
				{
					$half_path = "$parent";
				}
			}

#  			$a = join('<-', reverse(@a));
#  			$b = join('->', @b);			
#  			$path = "$a<-$parent->$b";

			#--- if the node is one of the ancestors of the target, then $#a will be -1 since @a does not contain anything. in that case $c is actually $parent. ---#
			#--- this is only required in case we are checking how many arguments were present in the same noun phrase as the target and what is the average length of ---#
			#--- this agrument ---#

			if( $#a == -1 )
			{
				$c = $parent;
			}
			else
			{
				$c = $a[$#a];
			}

			@path_parts = split("-", $path);
			
			for $i (0..12)
			{
				push(@path_parts, "U");
			}
			
			undef @path_trigram_list;
			for $i (0..10)
			{
				undef @temp;
				push(@temp, $path_parts[$i]);
				push(@temp, $path_parts[$i+1]);
				push(@temp, $path_parts[$i+2]);
				push(@path_trigram_list, join("-", @temp));
			}

			if( $DEBUG == $TRUE )
			{
				for $i (0..$#path_trigram_list)
				{
					print $path_trigram_list[$i], "\n";
				}
			}

			$path_trigrams = join(" ", @path_trigram_list);
			#exit;
			
			#---- skip constituents that are ancestors of target ----#
			#next unless $a;      


			if( $NE == $TRUE )
			{
				if( $ONLY_TEMP_AND_LOC == $TRUE )
				{
					#--- find the ne in this constituent for the NE feature ---#
					@ne_list = $sub =~ /(ne_[LTDltd][A-Z][A-Z]*)/g;
					
					
					if( $#ne_list != -1 )
					{
						$ne_in_constituent = $ne_list[0];
						#print STDERR "ne found is: $ne_in_constituent\n";
					}
					else
					{
						$ne_in_constituent = NONE;
						#print STDERR "ne found is: NONE\n";
					}
				}
				else
				{
					#--- find the ne in this constituent for the NE feature ---#
					@ne_list = $sub =~ /(ne_[A-Z][A-Z]*)/g;
					
					
					if( $#ne_list != -1 )
					{
						for $a_ne (@ne_list)
						{
							$ne_hash{$a_ne} = 1;
						}

						#$ne_in_constituent = $ne_list[0];
						#print STDERR "ne found is: $ne_in_constituent\n";
					}
					else
					{
						#$ne_in_constituent = NONE;
						#print STDERR "ne found is: NONE\n";
					}
				}

				$binary_ne_features_string = "";
				for $a_ne ( "ne_PERSON", "ne_ORGANIZATION", "ne_DATE", "ne_TIME", "ne_MONEY", "ne_LOCATION", "ne_PERCENT" )
				{
					if( exists $ne_hash{$a_ne} )
					{
						$binary_ne_features_string = "$binary_ne_features_string 1";
					}
					else
					{
						$binary_ne_features_string = "$binary_ne_features_string 0";
					}
				}
			}

			#---------------- getting cluster membership information --------------------#
			$head_word = $head;
			$head_word_pos = $head_pos_hash{$i}{$j};
			
			#--- first we do have to check whether it is a verb/noun or something else ---#
			if( $head_word_pos =~ /^V/ )
			{
				if( defined $vcid_hash{$head_word} )
				{
					$head_mx_prob_index = $vcid_hash{$head_word};
					$head_verb_cluster_def++;
				}
				else
				{
					#--- we do not have any cluster information on it ---#
					$head_mx_prob_index = "undefined";
					$head_verb_cluster_undef++;
				}
			}
			elsif( $head_word_pos =~ /^N/ )
			{
				#--- the target is a verb ---#
				if( defined $ncid_hash{$head_word} )
				{
					$head_mx_prob_index = $ncid_hash{$head_word};
					$head_noun_cluster_def++;
				}
				else
				{
					#--- we do not have any cluster information on it ---#
					$head_mx_prob_index = "undefined";
					$head_noun_cluster_undef++;
				}
			}
			else
			{
				#--- we do not have any cluster information on it ---#
				#$head_word_pos = "other";
				$head_mx_prob_index = "undefined";
				$head_other_cluster_undef++;
			}

			$head_word_cluster = "$head_word_pos-cluster-$head_mx_prob_index";

			if( $HEAD_POS == $TRUE )
			{
				#--- here we assign the right value to head ---#
				#$head = $head_word_pos;
			}
			
			if( $HEAD_POS_CLUSTER == $TRUE )
			{
				$head = "$head_word_pos-cluster-$head_mx_prob_index";
			}
			
			#print "word $word belongs to $word_pos-cluster-$mx_prob_index\n";
			#----------------------------------------------------------------------------#
            #---- score based on plain path -- to any target ----#
            #$score = $path_prob{$path};
            #----------------------------------------------------#
			
            #---- Backoff to the path to any target, if the given target is not seen ----#
            #if (defined $path_t_prob{"$path->$target"}) 
			#{
            #    $score = $path_t_prob{"$path->$target"};
            #} 
			#else 
			#{
            #    $score = $path_prob{"$path"};
            #}
			#----------------------------------------------------------------------------#

			#---- score based on the linear interpolation of path to ANY target and to the specific target (if any) ----#
			#---- irrespective of whether the given target was seen before                                          ----#
#  			if( $ONLY_HEAD != $TRUE )
#  			{
#  				#print STDERR "using path information\n";
#  				if( $NO_BACKOFF == $TRUE )
#  				{
#  					$score_p = $path_prob{$path} * 0.5 + $path_t_prob{"$path->$target"} * 0.5;
#  				}
				
#  				if( $BACKOFF == $TRUE )
#  				{
#  					if( defined $path_t_prob{"$path->$target"} )
#  					{
#  						$score_p = ($path_prob{$path} * .5 + $path_t_prob{"$path->$target"} * .5);
#  					}
#  					elsif( defined $path_c_prob{"$path->$word_pos-cluster-$mx_prob_index"} )
#  					{
#  						$score_p = ($path_prob{$path} * 0.5 + $path_c_prob{"$path->$word_pos-cluster-$mx_prob_index"} * 0.5);
#  					}
#  					else
#  					{
#  						$score_p = $path_prob{$path};
#  					}
#  				}

#  				if( $INTERPOLATION == $TRUE )
#  				{
#  					$score_p = ( $path_t_prob{"$path->$target"} + $path_c_prob{"$path->$word_pos-cluster-$mx_prob_index"} + $path_prob{$path} )/3.0;
#  				}
				
#  				if( $LM_BASED_ESTIMATION == $TRUE )
#  				{
#  				}
#  			}
#  			#-----------------------------------------------------------------------------------------------------------#
			
#  			if ( $ONLY_PATH != $TRUE ) 
#  			{
#  				#print "using head information\n";
#  				if( $NO_BACKOFF == $TRUE )
#  				{
#  					$score_h = $t_h{$target}{$head};   #--- target cluster and head cluster was not used previously ---#
#  				}

#  				if( $BACKOFF == $TRUE )
#  				{
#  					if( defined $t_h{$target}{$head} )
#  					{
#  						$score_h = $t_h{$target}{$head};
#  					}
#  					elsif( defined $c_h{"$word_pos-cluster-$mx_prob_index"}{$head} )
#  					{
#  						$score_h = $c_h{"$word_pos-cluster-$mx_prob_index"}{$head};
#  					}
#  					else
#  					{
#  						$score_h = $h_prob{$head};
#  					}
#  				}

#  				if( $INTERPOLATION == $TRUE )
#  				{
#  					$score_h = ($t_h{$target}{$head} + $c_h{"$word_pos-cluster-$mx_prob_index"}{$head} + $h_prob{$head} + $t_hc{$target}{$head_word_cluster} + $c_hc{"$word_pos-cluster-$mx_prob_index"}{$head_word_cluster} + $hc_prob{$head_word_cluster})/6.0;
#  				}

#  				if( $LM_BASED_ESTIMATION == $TRUE )
#  				{
#  				}
#  			}

#  			if( $ONLY_HEAD == $TRUE )
#  			{
#  				#---- combine the two scores ---#
#  				$score = $score_h;
#  			}
#  			elsif( $ONLY_PATH == $TRUE )
#  			{
#  				#---- combine the two scores ---#
#  				$score = 0.75 * $score_p;
#  			}
#  			else
#  			{
#  				#---- combine the two scores ---#
#  				$score = 0.75 * $score_p + 0.25 * $score_h;
#  			}
#  #	        $score = ($path_prob{$path} ** .75 * $t_h{$target}{$head} ** .25);
#  #	        if ($score) 
#  #           {
#  #		      $score /= (($path_prob{$path} ** .75 * $t_h{$target}{$head} ** .25) + ((1-$path_prob{$path}) ** .75 * (1-$t_h{$target}{$head}) ** .25));
#  #    	    }
			
			$score = 0;

			if( $old_feature_value_style == $TRUE )
			{
				$before = $targetpos < $j ? "after" : "before";
			}
			else
			{
				$before = $targetpos < $j ? "a" : "b";
			}

			if( $targetpos > $i && $targetpos < $j )
			{
				$before = "t";
			}

#   	    $score_path{"$target $head $path"} = $score;
			
			$target =~ s/\.v//;
			$target =~ s/\.n//;

			if( $old_feature_value_style == $TRUE )
			{
				if( defined $pass{$tpos} )
				{
					$passive = "PASS";
				}
				else
				{
					$passive = "ACTIVE";
				}
			}
			else
			{
				if( defined $pass{$tpos} )
				{
					$passive = "p";
				}
				else
				{
					$passive = "a";
				}
			}

			#print "score $score\n";

			if ($score >= $THRESHOLD) 
			{
				if( $is_fe eq "")
				{
					$is_fe = "O";
				}
				else
				{
					$is_fe = uc($is_fe);
				}

				if( $NULL_NON_NULL == $TRUE)
				{
					if( $is_fe ne "O" )
					{
						$is_fe = "NON-O";
					}
				}

				$head =~ s/ +//;
				if( $head eq "" )
				{
					$head = "U";
				}
				
				if($path eq "")
				{
					$path = "U";
				}

				if($target eq "")
				{
					$target = "U";
				}

				#--- create another half path feature ---#
				$half_path = $path;
				$half_path =~ s/->.*$//g;


				#print STDERR "word before target: ", $targetpos-1, " ", $n_some_array[$targetpos-1], "\n";
				#print STDERR join(' ', @n_some_array);
				
				#--- set the genetive flag NOT JUST 's, but POS ---#
				if( $n_hpos_some_array[$targetpos-1] eq "POS" )
				{
					$genetive = "1";
				}
				else
				{
					$genetive = "0";
				}

				#--- instead of checking the word ending, we will check whether the POS is NNS or NN ---#
				@split_string = split('', $n_hpos_some_array[$targetpos]);
				$a_word = $split_string[$#split_string];
				#print STDERR "a word: $a_word\n";
					
				if( $a_word eq "S" )
				{
					$plural = "1";
				}
				else
				{
					$plural = "0";
				}

				if( $DEBUG == $TRUE )
				{
					print "POS CONSTITUENT: ", join(' ', @n_hpos_some_array[$i..$j]), "\n";
				}
				
				#--- also check the POS of the last token in the constituent ---#
				if( $n_hpos_some_array[$j] eq "POS" || $n_hpos_some_array[$j] eq "PRP\$" || $n_hpos_some_array[$j] eq "WP\$" || $n_hpos_some_array[$j] eq "PRP" )
				{
					$genetive_phrase = "1";
				}
				else
				{
					$genetive_phrase = "0";
				}
				
				#--- add the first and last word in the constituent ---#
				$first_word_in_constituent = $n_some_array[$i];
				$last_word_in_constituent  = $n_some_array[$j];

				#--- add the first and last word POS in the constituent ---#
				$first_pos_in_constituent  = $n_hpos_some_array[$i];
				$last_pos_in_constituent   = $n_hpos_some_array[$j];

				$first_word_in_constituent =~ s/ +//;
				if( $first_word_in_constituent eq "" )
				{
					$first_word_in_constituent = "U";
				}

				$last_word_in_constituent =~ s/ +//;
				if( $last_word_in_constituent eq "" )
				{
					$last_word_in_constituent = "U";
				}

				$first_pos_in_constituent =~ s/ +//;
				if( $first_pos_in_constituent eq "" )
				{
					$first_pos_in_constituent = "U";
				}

				$last_pos_in_constituent =~ s/ +//;
				if( $last_pos_in_constituent eq "" )
				{
					$last_pos_in_constituent = "U";
				}

				#--- add words and pos window around target ---#
				#--- in order to do that, lets add the tokens </s> and <s> before and after the sentences ---#
				#--- so that the boundary case is taken case of automatically, also add 2 to the targetpos ---#
				@new_n_some_array = @n_some_array;
				$new_targetpos = $targetpos + 2;
				$new_i = $i+2;
				$new_j = $j+2;
				unshift(@new_n_some_array, "<s>");
				unshift(@new_n_some_array, "</s>");
				push(@new_n_some_array, "</s>");
				push(@new_n_some_array, "<s>");
				

				@new_n_hpos_some_array = @n_hpos_some_array;
				$new_targetpos = $targetpos + 2;
				unshift(@new_n_hpos_some_array, "<s>");
				unshift(@new_n_hpos_some_array, "</s>");
				push(@new_n_hpos_some_array, "</s>");
				push(@new_n_hpos_some_array, "<s>");
				
				$target_minus_2_word = lc($new_n_some_array[$new_targetpos-2]);
				$target_minus_1_word = lc($new_n_some_array[$new_targetpos-1]);
				$target_word         = lc($new_n_some_array[$new_targetpos]);
				$target_plus_1_word  = lc($new_n_some_array[$new_targetpos+1]);
				$target_plus_2_word  = lc($new_n_some_array[$new_targetpos+2]);

				$target_minus_2_pos = $new_n_hpos_some_array[$new_targetpos-2];
				$target_minus_1_pos = $new_n_hpos_some_array[$new_targetpos-1];
				$target_pos         = $new_n_hpos_some_array[$new_targetpos];
				$target_plus_1_pos  = $new_n_hpos_some_array[$new_targetpos+1];
				$target_plus_2_pos  = $new_n_hpos_some_array[$new_targetpos+2];
				#-----------------------------------------------------------------#


				$constituent_left_bound_minus_2_word = lc($new_n_some_array[$new_i-2]);
			    $constituent_left_bound_minus_1_word = lc($new_n_some_array[$new_i-1]);
				#-- constieuent_left_bound_minus_0_word = first_word_in_constituent
				$constituent_left_bound_plus_1_word = lc($new_n_some_array[$new_i+1]);
				$constituent_left_bound_plus_2_word = lc($new_n_some_array[$new_i+2]);

				$constituent_left_word_context = "$constituent_left_bound_minus_2_word $constituent_left_bound_minus_1_word $constituent_left_bound_plus_1_word $constituent_left_bound_plus_2_word";

				$constituent_left_bound_minus_2_pos = $new_n_hpos_some_array[$new_i-2];
			    $constituent_left_bound_minus_1_pos = $new_n_hpos_some_array[$new_i-1];
				#-- constieuent_left_bound_minus_0_pos = first_pos_in_constituent
				$constituent_left_bound_plus_1_pos = $new_n_hpos_some_array[$new_i+1];
				$constituent_left_bound_plus_2_pos = $new_n_hpos_some_array[$new_i+2];

				$constituent_left_pos_context = "$constituent_left_bound_minus_2_pos $constituent_left_bound_minus_1_pos $constituent_left_bound_plus_1_pos $constituent_left_bound_plus_2_pos";

				$constituent_right_bound_minus_2_word = lc($new_n_some_array[$new_j-2]);
			    $constituent_right_bound_minus_1_word = lc($new_n_some_array[$new_j-1]);
				#-- constieuent_right_bound_minus_0_word = last_word_in_constituent
				$constituent_right_bound_plus_1_word = lc($new_n_some_array[$new_j+1]);
				$constituent_right_bound_plus_2_word = lc($new_n_some_array[$new_j+2]);
				
				$constituent_right_word_context = "$constituent_right_bound_minus_2_word $constituent_right_bound_minus_1_word $constituent_right_bound_plus_1_word $constituent_right_bound_plus_2_word";

				$constituent_right_bound_minus_2_pos = $new_n_hpos_some_array[$new_j-2];
			    $constituent_right_bound_minus_1_pos = $new_n_hpos_some_array[$new_j-1];
				#-- constieuent_right_bound_minus_0_pos = last_pos_in_constituent
				$constituent_right_bound_plus_1_pos = $new_n_hpos_some_array[$new_j+1];
				$constituent_right_bound_plus_2_pos = $new_n_hpos_some_array[$new_j+2];
				
				$constituent_right_pos_context = "$constituent_right_bound_minus_2_pos $constituent_right_bound_minus_1_pos $constituent_right_bound_plus_1_pos $constituent_right_bound_plus_2_pos";
				



				if( $head eq "" )
				{
					$head = "U";
				}

				if( $head_word_pos eq "" )
				{
					$head_word_pos = "U";
				}

				if( $target_minus_2_word eq "" )
				{
					$target_minus_2_word = "U";
				}

				if( $target_minus_1_word eq "" )
				{
					$target_minus_1_word = "U";
				}

				if( $target_word eq "" )
				{
					$target_word = "U";
				}

				if( $target_plus_1_word eq "" )
				{
					$target_plus_1_word = "U";
				}

				if( $target_plus_2_word eq "" )
				{
					$target_plus_2_word = "U";
				}


				if( $target_minus_2_pos eq "" )
				{
					$target_minus_2_pos = "U";
				}

				if( $target_minus_1_pos eq "" )
				{
					$target_minus_1_pos = "U";
				}

				if( $target_pos eq "" )
				{
					$target_pos = "U";
				}

				if( $target_plus_1_pos eq "" )
				{
					$target_plus_1_pos = "U";
				}

				if( $target_plus_2_pos eq "" )
				{
					$target_plus_2_pos = "U";
				}

				@target_chars = split("", $n_some_array[$targetpos]);
				if( ($#target_chars-2) >= 0 )
				{
					$target_suffix_minus_2 = $target_chars[$#target_chars-2];
				}
				else
				{
					$target_suffix_minus_2 = "U";
				}
				#print $target_suffix_minus_2, "\n";

				if( ($#target_chars-1) >= 0 )
				{
					$target_suffix_minus_1 = $target_chars[$#target_chars-1];
				}
				else
				{
					$target_suffix_minus_1 = "U";
				}
				#print $target_suffix_minus_1, "\n";

				$target_suffix_minus_0 = $target_chars[$#target_chars];
				
				if($target_suffix_minus_0 eq "")
				{
					$target_suffix_minus_0 = "U";
				}
				#print "target_suffix: ", $target_suffix_minus_0, "\n";

				$last_two_target_suffix = "$target_suffix_minus_1$target_suffix_minus_0";
				$last_three_target_suffix = "$target_suffix_minus_2$target_suffix_minus_1$target_suffix_minus_0";

				#print $last_two_target_suffix, "\n";
				#print $last_three_target_suffix, "\n";

				
				@head_chars = split("", $head);
				if( ($#head_chars-2) >= 0 )
				{
					$head_suffix_minus_2 = $head_chars[$#head_chars-2];
				}
				else
				{
					$head_suffix_minus_2 = "U";
				}
				#print $head_suffix_minus_2, "\n";

				if( ($#head_chars-1) >= 0 )
				{
					$head_suffix_minus_1 = $head_chars[$#head_chars-1];
				}
				else
				{
					$head_suffix_minus_1 = "U";
				}
				#print $head_suffix_minus_1, "\n";

				$head_suffix_minus_0 = $head_chars[$#head_chars];
				#print $head_suffix_minus_0, "\n";


				$last_two_head_suffix = "$head_suffix_minus_1$head_suffix_minus_0";
				$last_three_head_suffix = "$head_suffix_minus_2$head_suffix_minus_1$head_suffix_minus_0";

				#print $last_two_head_suffix, "\n";
				#print $last_three_head_suffix, "\n";



				#--- broken path ---#

				undef @path_tokens;
				@path_tokens = split("-", $path);

				for $i ( 0..10 )
				{
					push(@path_token, "U");
				}

				undef $broken_path;
				$broken_path = join(" ", @path_tokens[0..4]);
				if( $DEBUG == $TRUE )
				{
					print $broken_path, "\n";
				}
				#exit;
				#-------------------#


				#--- path from the constituent to the FIRST light verb/being verb/any verb between constituent and the target ---#
				

				#----------------------------------------------------------------------------------------------------------------#
				# we will designate the verbs with the following suffixes.  none: for verb nearest to predicate and beteween the
				# constituent; 1: for verb nearest to the constituent and between constituent and predicate and 2: verb nearest to
				# constituent and beteween constituent and start/end of sentence depending on whether the constituent is before
				# or after the predicate
				#----------------------------------------------------------------------------------------------------------------#

				#--- light verb ---#
				$path_to_light_verb = "U";
				$is_light_verb = 0;
				$light_verb = "U";

				$path_to_light_verb_1 = "U";
				$is_light_verb_1 = 0;
				$light_verb_1 = "U";

				$path_to_light_verb_2 = "U";
				$is_light_verb_2 = 0;
				$light_verb_2 = "U";

				if( $j < $targetpos )
				{
					for ( $ii=$targetpos-1; $ii>$j; $ii-- )
					{
						if( $n_some_array[$ii] =~ /\b(took|take|make|made|give|gave|went|go)\b/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;

							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_light_verb = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$light_verb = $n_some_array[$ii];
							$is_light_verb = 1;

							last;
						}

						#print "$n_some_array[$ii]\n";
					}


					for ( $ii=$j+1; $ii<$targetpos; $ii++ )
					{
						if( $n_some_array[$ii] =~ /\b(took|take|make|made|give|gave|went|go)\b/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;

							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_light_verb_1 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$light_verb_1 = $n_some_array[$ii];
							$is_light_verb_1 = 1;

							last;
						}

						#print "$n_some_array[$ii]\n";
					}



					for ( $ii=$i-1; $ii>0; $ii-- )
					{
						if( $n_some_array[$ii] =~ /\b(took|take|make|made|give|gave|went|go)\b/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;

							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_light_verb_2 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$light_verb_2 = $n_some_array[$ii];
							$is_light_verb_2 = 1;

							last;
						}

						#print "$n_some_array[$ii]\n";
					}

				}
				else
				{
					for ( $ii=$targetpos+1; $ii<$i; $ii++ )
					{
						if( $n_some_array[$ii] =~ /\b(took|take|make|made|give|gave|went|go)\b/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;

							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_light_verb = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$light_verb = $n_some_array[$ii];
							$is_light_verb = 1;

							last;
						}

						#print "$n_some_array[$ii]\n";
					}


					for ( $ii=$i-1; $ii>$targetpos; $ii-- )
					{
						if( $n_some_array[$ii] =~ /\b(took|take|make|made|give|gave|went|go)\b/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;

							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_light_verb_1 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$light_verb_1 = $n_some_array[$ii];
							$is_light_verb_1 = 1;

							last;
						}

						#print "$n_some_array[$ii]\n";
					}



					for ( $ii=$j+1; $ii<$#n_some_array; $ii++ )
					{
						if( $n_some_array[$ii] =~ /\b(took|take|make|made|give|gave|went|go)\b/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;

							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_light_verb_2 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$light_verb_2 = $n_some_array[$ii];
							$is_light_verb_2 = 1;

							last;
						}

						#print "$n_some_array[$ii]\n";
					}

				}
				#--------------------------------------------------#

				#--- being verb ---#
				$path_to_being_verb = "U";
				$is_being_verb = 0;
				$being_verb = "U";

				$path_to_being_verb_1 = "U";
				$is_being_verb_1 = 0;
				$being_verb_1 = "U";

				$path_to_being_verb_2 = "U";
				$is_being_verb_2 = 0;
				$being_verb_2 = "U";



				if( $j < $targetpos )
				{
					for ( $ii=$targetpos-1; $ii>$j; $ii-- )
					{
						if( $n_hpos_some_array[$ii] =~ /AUX/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_being_verb = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$being_verb = $n_some_array[$ii];
							$is_being_verb = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}


					for ( $ii=$j+1; $ii<$targetpos; $ii++ )
					{
						if( $n_hpos_some_array[$ii] =~ /AUX/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_being_verb_1 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$being_verb_1 = $n_some_array[$ii];
							$is_being_verb_1 = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}


					for ( $ii=$i-1; $ii>0; $ii-- )
					{
						if( $n_hpos_some_array[$ii] =~ /AUX/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_being_verb_2 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$being_verb_2 = $n_some_array[$ii];
							$is_being_verb_2 = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}

				}
				else
				{
					for ( $ii=$targetpos+1; $ii<$i; $ii++ )
					{
						if( $n_hpos_some_array[$ii] =~ /AUX/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_being_verb = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$being_verb = $n_some_array[$ii];
							$is_being_verb = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}


					for ( $ii=$i-1; $ii>$targetpos; $ii-- )
					{
						if( $n_hpos_some_array[$ii] =~ /AUX/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_being_verb_1 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$being_verb_1 = $n_some_array[$ii];
							$is_being_verb_1 = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}


					for ( $ii=$j+1; $ii<$#n_some_array; $ii++ )
					{
						if( $n_hpos_some_array[$ii] =~ /AUX/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};

							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_being_verb_2 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$being_verb_2 = $n_some_array[$ii];
							$is_being_verb_2 = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}
				}
				#--------------------------------------------------#

				#--- any verb ---#
				$path_to_verb = "U";
				$is_verb = 0;
				$verb    = "U";

				$path_to_verb_1 = "U";
				$is_verb_1 = 0;
				$verb_1    = "U";

				$path_to_verb_2 = "U";
				$is_verb_2 = 0;
				$verb_2    = "U";

				if( $j < $targetpos )
				{
					for ( $ii=$targetpos-1; $ii>$j; $ii-- )
					{
						if( $n_hpos_some_array[$ii] =~ /VB/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};
							
							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_verb = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$verb = $n_some_array[$ii];
							$is_verb = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}

					for ( $ii=$j+1; $ii<$targetpos; $ii++ )
					{
						if( $n_hpos_some_array[$ii] =~ /VB/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};
							
							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_verb_1 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$verb_1 = $n_some_array[$ii];
							$is_verb_1 = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}

					for ( $ii=$i-1; $ii>0; $ii-- )
					{
						if( $n_hpos_some_array[$ii] =~ /VB/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};
							
							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_verb_2 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$verb_2 = $n_some_array[$ii];
							$is_verb_2 = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}
				}
				else
				{
					for ( $ii=$targetpos+1; $ii<$i; $ii++ )
					{
						if( $n_hpos_some_array[$ii] =~ /VB/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};
							
							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_verb = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$verb = $n_some_array[$ii];
							$is_verb = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}

					for ( $ii=$i-1; $ii>$targetpos; $ii-- )
					{
						if( $n_hpos_some_array[$ii] =~ /VB/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};
							
							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_verb_1 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$verb_1 = $n_some_array[$ii];
							$is_verb_1 = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}

					for ( $ii=$j+1; $ii<$#n_some_array; $ii++ )
					{
						if( $n_hpos_some_array[$ii] =~ /VB/ )
						{
							if( $DEBUG == $TRUE )
							{
								print "'$highestpath{$i}{$j}'\n";
								print "'$highestpath{$ii}{$ii}'\n";
							}

							$a = $highestpath{$i}{$j};
							$b = $highestpath{$ii}{$ii};
							
							undef @a, @b;

							@a = split(/ /, $a);
							@b = split(/ /, $b);
							
							shift(@b);         # head word of target
							$head = shift(@a); # head word of constit
							
							while (@a && $a[0] && $a[0] eq $b[0]) 
							{
								# remove common substring of constituents in path from root
								$parent = shift(@a);
								shift(@b);
							}
							
							$parent =~ s/^<//;
							$parent =~ s/>-\d+//;
							map { s/^<//; s/>-\d+//; } @a;
							map { s/^<//; s/>-\d+//; } @b;

							$left_path = join($LEFT_PATH_SEPERATOR,  reverse(@a));
							$right_path = join($RIGHT_PATH_SEPERATOR, @b);

							$path_to_verb_2 = "$left_path$LEFT_PATH_SEPERATOR$parent$RIGHT_PATH_SEPERATOR$right_path";
							$verb_2 = $n_some_array[$ii];
							$is_verb_2 = 1;

							last;
						}

						#print "$n_hpos_some_array[$ii]\n";
					}
				}
				#--------------------------------------------------#

				if( $subcat eq "" )
				{
					$subcat = "U";
				}

				if( $DEBUG == $TRUE )
				{
					print "path from constituent to light-verb: $path_to_light_verb\n";
					print "path from constituent to being-verb: $path_to_being_verb\n";
					print "path from constituent to any-verb: $path_to_verb\n";
				}

				#----------------------- start setting temporal word flag (aka salient_vector) ----#
				
				if( $salient_words_opt )
				{

					#--- lets prepare the possible salient word combinations of the words in this constituent ---#
					if($DEBUG == $TRUE)
					{
						print "sub:$sub\n";
					}
					
					undef %cons_salient_words;
					
					for($iii=$i; $iii<=$j; $iii++)
					{
						#printf "adding '%s' to the hash\n", lc($orig_words[$iii]);
						$cons_salient_words{lc($n_some_array[$iii])}++;
						
						if($iii+1 <= $j)
						{
							#printf "adding '%s' to the hash\n", lc(join(";", @w[$iii..$iii+1]));
							$cons_salient_words{lc(join(";", @n_some_array[$iii..$iii+1]))}++;
						}
						
						if($iii+2 <= $j)
						{
							#printf "adding '%s' to the hash\n", lc(join(";", @w[$iii..$iii+2]));
							$cons_salient_words{lc(join(";", @n_some_array[$iii..$iii+2]))}++;
						}
					}
					
					if($DEBUG == $TRUE)
					{
						for $key (sort keys %cons_salient_words)
						{
							print "keys: $key\n";
						}
					}
					
					$salient_vector = "0";
					
					for $key (sort keys %salient_hash)
					{
						if($DEBUG == $TRUE)
						{
							print "key: '$key'\n";
						}
						if(exists $cons_salient_words{$key})
						{
							if($DEBUG == $TRUE)
							{
								print "$key exists\n";
							}
							#$salient_vector = "$salient_vector 1";
							$salient_vector = "1";
						}
						else
						{
							#print "! exists\n";
							#$salient_vector = "$salient_vector 0";
						}
					}
					
					#print "$salient_vector\n";
					
					$salient_vector =~ s/^  *//g;
					$salient_vector =~ s/  *$//g;
				}
				#----------------------- end setting temporal word flag (aka salient_vector) ----#

				
				if( !($ONLY_ROLES == $TRUE && $is_fe eq "O") ) 
				{

					if( $TARGET_HEAD_POSN == $TRUE )
					{
					$targetpos_head_posn_concat = $targetpos."_".$head_ind_hash{$i}{$j};
					print "$tpos $targetpos_head_posn_concat $i $j $c $target $frame $head $head_word_pos $light_verb $being_verb $verb $is_light_verb $is_being_verb $is_verb $before $path $half_path $path_to_light_verb $path_to_being_verb $path_to_verb $subcat $genetive $genetive_phrase $plural $first_word_in_constituent $last_word_in_constituent $first_pos_in_constituent $last_pos_in_constituent $word_pos-cluster-$mx_prob_index $passive $binary_ne_features_string $clause $target_minus_2_word $target_minus_1_word $target_word $target_plus_1_word $target_plus_2_word $target_minus_2_pos $target_minus_1_pos $target_pos $target_plus_1_pos $target_plus_2_pos $target_suffix_minus_2 $target_suffix_minus_1 $target_suffix_minus_0 $last_three_target_suffix $last_two_target_suffix $head_suffix_minus_2 $head_suffix_minus_1 $head_suffix_minus_0 $last_three_head_suffix $last_two_head_suffix $left_path_string $parent_string $right_path_string $one_char_path $path_trigrams $path_center_left_n_grams_string $path_center_right_n_grams_string $path_only_clause_left_string<-$parent_clause_string->$path_only_clause_right_string $path_clause_other_asterix_left_string<-$parent_clause_other_asterix_string->$path_clause_other_asterix_right_string $path_clause_flag $light_verb_1 $being_verb_1 $verb_1 $is_light_verb_1 $is_being_verb_1 $is_verb_1 $path_to_light_verb_1 $path_to_being_verb_1 $path_to_verb_1 $light_verb_2 $being_verb_2 $verb_2 $is_light_verb_2 $is_being_verb_2 $is_verb_2 $path_to_light_verb_2 $path_to_being_verb_2 $path_to_verb_2 $salient_vector $lex_path $is_fe\n";
				}
					else
					{
					print "$tpos $targetpos $i $j $c $target $frame $head $head_word_pos $light_verb $being_verb $verb $is_light_verb $is_being_verb $is_verb $before $path $half_path $path_to_light_verb $path_to_being_verb $path_to_verb $subcat $genetive $genetive_phrase $plural $first_word_in_constituent $last_word_in_constituent $first_pos_in_constituent $last_pos_in_constituent $word_pos-cluster-$mx_prob_index $passive $binary_ne_features_string $clause $target_minus_2_word $target_minus_1_word $target_word $target_plus_1_word $target_plus_2_word $target_minus_2_pos $target_minus_1_pos $target_pos $target_plus_1_pos $target_plus_2_pos $target_suffix_minus_2 $target_suffix_minus_1 $target_suffix_minus_0 $last_three_target_suffix $last_two_target_suffix $head_suffix_minus_2 $head_suffix_minus_1 $head_suffix_minus_0 $last_three_head_suffix $last_two_head_suffix $left_path_string $parent_string $right_path_string $one_char_path $path_trigrams $path_center_left_n_grams_string $path_center_right_n_grams_string $path_only_clause_left_string<-$parent_clause_string->$path_only_clause_right_string $path_clause_other_asterix_left_string<-$parent_clause_other_asterix_string->$path_clause_other_asterix_right_string $path_clause_flag $light_verb_1 $being_verb_1 $verb_1 $is_light_verb_1 $is_being_verb_1 $is_verb_1 $path_to_light_verb_1 $path_to_being_verb_1 $path_to_verb_1 $light_verb_2 $being_verb_2 $verb_2 $is_light_verb_2 $is_being_verb_2 $is_verb_2 $path_to_light_verb_2 $path_to_being_verb_2 $path_to_verb_2 $salient_vector $lex_path $is_fe\n";
					$head_posn = $head_ind_hash{$i}{$j};
					print HEAD_WORD_MAP "$tpos $targetpos $i $j $head_posn\n";
				}

					#--- if the argument is not null, then tag the head word in the original string with the argument tag ---#
					if( $is_fe ne "O" )
					{
						$n_head_tagged_some_array[$head_ind_hash{$i}{$j}] = "<C FE=\"$is_fe\"> ".$n_head_tagged_some_array[$head_ind_hash{$i}{$j}]." </C>";
					}

#-- removed the path context strings ---#
#$path_left_context_string $path_right_context_string 


					$SOME_FEATURES_PRINTED = $TRUE;
					#exit;
				}
			}
			else
			{
				if($is_fe ne "")
				{
					$missed++;
				}
			}
		}
    }

	#--- add the prefix and suffix to the head tagged sentence to make it just like the tagged line in input ---#
	$n_head_tagged_some_array[0] = "$prefix ".$n_head_tagged_some_array[0];
	$n_head_tagged_some_array[$#n_head_tagged_some_array] = $n_head_tagged_some_array[$#n_head_tagged_some_array]." </S>";

	$string = join(' ', @n_some_array);
	$head_tagged_string = join(' ', @n_head_tagged_some_array);
	

	if( $SOME_FEATURES_PRINTED == $TRUE )
	{
		#print "++$string\n";
		print "\n";
		print SEN "$string\n";
		print HEAD_TAGGED "$head_tagged_string\n";
		print HEAD_TAGGED "$original_parse";

		if($NE == $TRUE )
		{
			print HEAD_TAGGED "$ne\n";
		}
		
		print HEAD_WORD_MAP "\n";
	}

	#print ">> $original_parse\n";
}

print STDERR "missed fes: $missed\n";
print STDERR "mismatches: $mismatch\n";

print STDERR "cluster target coverage statistics:\n";

if($verb_cluster_def + $verb_cluster_undef > 0)
{
	printf STDERR "verb (percent covered): %0.3f (%d)\n", $verb_cluster_def/($verb_cluster_def + $verb_cluster_undef), $verb_cluster_def + $verb_cluster_undef;
}

if($noun_cluster_def + $noun_cluster_undef > 0)
{
	printf STDERR "noun (percent covered): %0.3f (%d)\n", $noun_cluster_def/($noun_cluster_def + $noun_cluster_undef), $noun_cluster_def + $noun_cluster_undef;
}

#printf STDERR "others: $other_cluster_undef\n" if defined $other_cluster_undef;

if( $HEAD_POS_CLUSTER )
{
	print STDERR "cluster headword coverage statistics:\n";
	
	if($head_verb_cluster_def + $head_verb_cluster_undef > 0)
	{
		printf STDERR "head verb (percent covered): %0.3f (%d)\n", $head_verb_cluster_def/($head_verb_cluster_def + $head_verb_cluster_undef), $head_verb_cluster_def + $head_verb_cluster_undef;
	}
	
	if($head_noun_cluster_def + $head_noun_cluster_undef > 0)
	{
		printf STDERR "head noun (percent covered): %0.3f (%d)\n", $head_noun_cluster_def/($head_noun_cluster_def + $head_noun_cluster_undef), $head_noun_cluster_def + $head_noun_cluster_undef;
	}
	
	printf STDERR "others: $head_other_cluster_undef\n" if defined $head_other_cluster_undef;
}
	
sub set_byte_swap 
{
	$endian_test = pack("i", 0x44332211);
    @endian_test = unpack("C4", $endian_test);
    if ($endian_test[0] == 0x11 && $endian_test[1] == 0x22 && 
		$endian_test[2] == 0x33 && $endian_test[3] == 0x44) 
	{
		#    Endian = LITTLE_ENDIAN;
		$byte_swap = 1;
    } 
	elsif ($endian_test[0] == 0x44 && $endian_test[1] == 0x33 && 
		   $endian_test[2] == 0x22 && $endian_test[3] == 0x11) 
	{
		#    Endian = BIG_ENDIAN;
		$byte_swap = 0;
    } 
	else 
	{
		printf(STDERR "Failed to determine endianness assuming little endian\n");
    }
}

sub read_float 
{
    my($p) = @_;
    if ($byte_swap) 
	{
		unpack('f', pack('c4', reverse(unpack('c4', $p))));
    } else 
	{
		unpack('f', $p);
    }
}

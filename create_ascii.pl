#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my $line_length = 80;
my $help = 0;
GetOptions(
  'l|length=i' => \$line_length,
  'h|help'     => \$help
);

if($help > 0) {
  Usage();
  exit;
}

my $inf;
if(defined($ARGV[0])) {
	$inf = $ARGV[0];
} else {
	print "USAGE: $0 file.tex\n;";
	exit;
}
unless($inf =~ /\.tex$/) {
	print "$inf is not a tex file\n";
	exit;
}

my $final_line = "";

process($inf);

PrintFinal($final_line);

sub PrintFinal
{
	my $whole = shift;
	my @tmp = split(/\n/,$whole);
	my $new_cnt = 0;
	foreach my $ent (@tmp) {
		if($ent =~ /^\s*$/) {
			$new_cnt++;
			if($new_cnt < 2) {
				print "\n";
			}
		} else {
			$new_cnt = 0;
      PrintMax("$ent",$line_length);
		}
	}
}

sub PrintMax
{
  my $ln = shift;
  my $len = shift;

  if(length $ln <= $len) {
    print "$ln\n";
    return;
  }

  my $pre = 0;
  my $first = 1;
  my @lines = SplitLine($ln,$len);
  foreach my $l (@lines) {
    if($first == 1) {
      if($l =~ /^(\s*-\s+)/) {
        $pre = length($1);
      }
      $first = 0;
      print "$l\n";
      next;
    }
    print " "x$pre;
    print "$l\n";
  }
}

sub SplitLine
{
  my $ln = shift;
  my $len = shift;

  my @out = ("");
  my $ind = 0;
  my @tmp = split /\s+/,$ln;
  while(scalar(@tmp) > 0) {
    while(length($out[$ind]) < $len) {
      my $c = shift @tmp;
      if(not defined($c)) {
      	# Nothing left....
	return @out;
      }
      $out[$ind] .= "$c ";
    }
    push @out, "";
    $ind++;
  }
  return @out;
}


sub process
{
	my $f = shift;
	local *IN;
	open IN, "$f" or die "Could not open $f to edit\n";
	my $start = 0;
	my $ascii_block = 0;
	my $itemize = 0;
	my $descitem = 0;

	while(my $line = <IN>) {
		chomp($line);
		if($start == 0 and $line =~ /%START ASCII/) {
			$start = 1;
			next;
		}
		next if($start == 0);

		if($line =~ /%END ASCII/) {
			last;
		}
		next if($line =~ /%ASCII IGNORE/);

		if($ascii_block == 0 and $line =~ /%ASCII BLOCK BEGIN/) {
			$ascii_block = 1;
			next;
		}
		if($line =~ /%ASCII BLOCK END/) {
			$ascii_block = 0;
			next;
		}
		if($ascii_block == 1) {
			if($line =~ /%(.+)$/) {
				$final_line .= "$1\n";
			}
			next;
		}

		# IGNORE COMMENTS
		next if($line =~ /^\s*%/);

		# Strip comments from the line
		if($line =~ /^(.+)%/) {
			if($1 !~ /\\$/) {
				$line = $1;
			}
		}

		# Follow files
		if($line =~ /\\input{(.+)}/) {
			my $ff = "$1.tex";
			process($ff);
			next;
		}

		# ADJUST FORMATTING
		$line =~ s/''/"/g;
		$line =~ s/\`\`/"/g;
		$line =~ s/\\%/%/g;
		$line =~ s/\\\\/\n/g;
		if($line =~ /(.*)\\textit{(.+)}(.*)$/) {
			$line = "$1$2$3";
		}

		# IGNORE PAGE BREAK
		next if($line =~ /\\pagebreak/);

  		# IGNORE BLANK LINES
		next if($line =~ /^\s*$/);


		# HEADING
		if($line =~ /\\resheading{(.+)}/) {
			PrintHeading($1);
			next;
		}

		# SUB HEADING
		if($line =~ /\\ressubheading{(.+)}{(.+)}{(.+)}{(.+)}/) {
			PrintSubHeading($1, $2, $3, $4);
			next;
		}

		# PARSE ITEMIZE BLOCKS
		if($itemize == 0 and $line =~ /\\begin{itemize}/) {
			$itemize = 1;
			next;
		}

		if($line =~ /\\end{itemize}/) {
			$itemize = 0;
			next;
		}
		if($itemize == 1 and $line =~ /\\resitem{(.+)}/) {
			my $in = $1;
			$final_line .= "- $in\n";
			next;
		}

		# PARSE DESC BLOCKS
		if($descitem == 0 and $line =~ /\\begin{description}/) {
			$descitem = 1;
			next;
		}
		if($line =~ /\\end{description}/) {
			$descitem = 0;
			next;
		}
		if($descitem == 1 and $line =~ /\\item\[(.+)\]/) {
			$final_line .= "\n$1\n";
			next;
		} elsif($descitem == 1) {
			$final_line .= "$line\n";
			next;
		}

		# Ignore any other commands
		if($line =~ /\\/) {
			print STDERR "Ignoring line (Unknown command): \"$line\"\n";
			next;
		}

		# DEFAULT
		$final_line .= "$line\n";
	}
	close(IN);
}

sub PrintHeading
{
	my $l = shift;
	my $len = length $l;
	$final_line .= "\n$l\n";
	$final_line .= "=" x $len;
	$final_line .= "\n\n";
}

sub PrintSubHeading
{
	my ($a,$b,$c,$d) = @_;
	my $len = length "$a  $b";
	$final_line .= "\n$a  $b\n";
	$final_line .= "-"x$len;
	$final_line .= "\n$c $d\n";
}

sub Usage
{
  print "USAGE: $0 [OPTIONS] MAIN_TEX_FILE.tex\n\n";
  print "OPTIONS:\n";
  print "-h|--help:\n";
  print "Print this message\n\n";
  print "-l|--length LENGTH\n";
  print "Use LENGTH as the max line length of the output text\n";
  print "Default: $line_length\n\n";
  print "MAIN_TEX_FILE.tex is the head latex file. any input files 
mentioned in this file is automatically parsed as long as they
are in the same directory.";
  print "\nNOTE: To avoid errors, the file extension is checked before parsing the file.\n";
}

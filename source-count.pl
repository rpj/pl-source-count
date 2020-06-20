#!/usr/bin/perl
##
# A TLOC Counter
#
# TODO: 
# + Get HTML output (with GD working)
#
# $Id: source-count.pl,v 1.2 2003/08/06 03:28:58 rjoseph Exp $

use File::Find;
use Getopt::Long;
use Time::HiRes qw(gettimeofday tv_interval);

my $start_time = [gettimeofday()];

my $opt_out_file     = '';
my $opt_out_frmt     = 'text';
my $opt_out_file     = '';
my $opt_long_out     = 0;
my $opt_debug        = 0;

my $ARR_CNT_ELE      = 0;
my $ARR_LOC_ELE      = 1;
my $ARR_CMNT_ELE     = 2;
my $ARR_FILE_HASH    = 3;

my $global_tloc_cnt  = 0;
my $global_line_cnt  = 0;
my $global_file_cnt  = 0;

my $defect_high      = 7;
my $defect_low       = 10;

# Quick explanation: 
# [file extension] => [ file_counter, tloc_counter, comment_style ]
# To add a file type, just leave the first two entries zero and amke
# the last a space-delimited set of comment types (C, CPP, or PERL)
my $file_types       = {
   'JAVA'         => [ 0, 0, 'CPP C' ],
   'CPP'          => [ 0, 0, 'CPP C' ],
   'C'            => [ 0, 0, 'CPP C'],
   'PL'           => [ 0, 0, 'PERL' ],
   'H'            => [ 0, 0, 'CPP C'],
   'RMOD'         => [ 0, 0, 'PERL' ],
   'PM'           => [ 0, 0, 'PERL' ],
   'CGI'          => [ 0, 0, 'PERL' ],
   'M'            => [ 0, 0, 'CPP C'],
   'MM'           => [ 0, 0, 'CPP C'],
   'ERL'          => [ 0, 0, 'ERL'],
   'PY'           => [ 0, 0, 'PERL'],
   'SH'           => [ 0, 0, 'PERL'],
   'SWIFT'        => [ 0, 0, 'CPP C'],
   'CS'           => [ 0, 0, 'CPP C'],
   'GO'           => [ 0, 0, 'CPP C'],
   'JS'           => [ 0, 0, 'CPP C'],
   };
   
GetOptions (
   'output:s'     => \$opt_out_file,
   'format:s'     => \$opt_out_frmt,
   'long-output!' => \$opt_long_out,
   'debug'        => \$opt_debug,
   'help'         => sub { __help(); },
   );

die "Must specify at least one search directory!\n\n", unless (@ARGV);
my $dirs_to_search = \@ARGV;

# START_MAIN Start the search
find (\&searcher, @{$dirs_to_search});
eval "${opt_out_frmt}_output()";
# END_MAIN

sub text_output {
   my $date = localtime();
   my $dir = `pwd`;
   my $ratio = sprintf("%0.2f" , 
      (($global_tloc_cnt / $global_line_cnt)*100));
   my $dlow = sprintf("%0.1f", $global_tloc_cnt / $defect_low);
   my $dhigh = sprintf("%0.1f", $global_tloc_cnt / $defect_high);
   my $elap = tv_interval($start_time);
   chomp($dir);

   my $text = "$global_file_cnt source files: " .
      "$global_tloc_cnt TLOC out of " .
      "$global_line_cnt total lines ($ratio\% code)\n" .
      "Defect estimates:\tLow: $dlow\tHigh: $dhigh\n" .
      "Search directories in $dir: ";
   foreach (@{$dirs_to_search}) { $text .= "$_ "; }
   $text .= "\n$date, search took $elap seconds.\n";
   $text .= "-" x 70 . "\n\n";

   foreach my $key (sort keys %{$file_types}) {
      if ($file_types->{$key}[$ARR_CNT_ELE]) {
         $avg->{$key} = sprintf("%0.1f", $file_types->{$key}[$ARR_LOC_ELE] /
          $file_types->{$key}[$ARR_CNT_ELE]);

         $text .= qq~** Files of type $key:\n~;
         $text .= qq~\t$file_types->{$key}[$ARR_CNT_ELE] files\n~;
         $text .= qq~\tTLOC Count: $file_types->{$key}[$ARR_LOC_ELE]\n~,
            if ($file_types->{$key}[$ARR_LOC_ELE]);
         $text .= qq~\tAverage TLOC/file: $avg->{$key}\n~, if ($avg->{$key});
         $text .= ' ' x 10 . '-' x 50 . "\n";

         if ($opt_long_out && $file_types->{$key}[$ARR_LOC_ELE]) {
            $text .= qq~\t\tLOC\tFile Name\n~ . ' ' x 15 . '-' x 40 . "\n";
            foreach (sort keys %{$file_types->{$key}[$ARR_FILE_HASH]}) {
               my $loc = $file_types->{$key}[$ARR_FILE_HASH]{$_};
               $text .= qq~\t\t$loc\t$_\n~;
            }

            $text .= ' ' x 10 . '-' x 50 . "\n";
         }

         $text .= "\n";
      }
   }

   __output($text);
}

sub html_output {
   __output("HTML output is not yet implemented.\n\n");
}

sub __output {
   if ($opt_out_file) { 
      open (OUT, "+>$opt_out_file") or
         die "Error opening $opt_out_file: $!\n\n";

      select(OUT);
   }

   print shift;
   close(OUT);
}

sub searcher {
   my $file = $_;
   my $cmnt_regex = '';
   my $cmnt_is_cpp = 0;
   my $multi_line = 0;
    
   if (-f $_) {
      foreach my $extn (keys %{$file_types}) {
         if (/^.*\.$extn$/i) {
            open (A, "$file") or
               die "Error opening $_ in " . `pwd` . ": $!\n\n";

            foreach ($file_types->{$extn}[$ARR_CMNT_ELE]) {
               chomp;
               
               foreach (split(" ")) {
                  $cmnt_regex .= '|', if $cmnt_regex;
                  
                  $cmnt_is_cpp = 1, if ($_ eq 'CPP');

                  $cmnt_regex .= '(^\s*\/\*.*\*\/\s*$)', if ($_ eq 'CPP');
                  $cmnt_regex .= '(^\s*\/\/.*$)', if ($_ eq 'C');
                  $cmnt_regex .= '(^\s*#.*$)', if ($_ eq 'PERL');
              $cmnt_regex .= '(^\s*%.*$)', if ($_ eq 'ERL');
               }
            }

            print "\tREGEX: $cmnt_regex\n", if ($opt_debug);
            while (<A>) {
               $global_line_cnt++;
               if ($_ !~ /$cmnt_regex/ims && $_ !~ /^\s*$/) {
                  print "**\t$_", if ($opt_debug);
                  chomp;

                  my $line = $_;
                  if ($cmnt_is_cpp) {
                     print "\tCMNT_IS_CPP, ml == $multi_line\n", if ($opt_debug);
                     if ((!$multi_line && $line =~ /^\s*\/\*.*?/ig)
                           || ($multi_line)) {
                        print "\tmulti_line = 1\n", if ($opt_debug);
                        $multi_line = 1;
                     } else {
                        print "\telse->ml = 0\n", if ($opt_debug);
                        $multi_line = 0;
                     }
                  }
                 
                  if (!$multi_line) {
                     print "\tCOUNTING!\n", if ($opt_debug);
                     $file_types->{$extn}[$ARR_LOC_ELE]++;
                     $file_types->{$extn}[$ARR_FILE_HASH]{"$File::Find::dir/$file"}++;
                     $global_tloc_cnt++;
                  }

                  $multi_line = 0, if ($cmnt_is_cpp && $line =~ /^.*?\*\//ig);
               }
            }

            close A;

            $file_types->{$extn}[$ARR_CNT_ELE]++;
            $global_file_cnt++;
         }
      }
   }
}

sub __help {
   print <<HELP_TEXT;
Usage: $0 [options] [dir1 [dir2..]]

NOTE: you can (depending on your shell, but this should work(tm)) specify file
globs to search, such as: $0 *.java

For the reported defect estimates, the numbers used are:
Low defect rate:\t1 defect in every $defect_low lines of code
High defect rate:\t1 defect in every $defect_high lines of code

   -h, --help        This help dialog
   -o, --ouput       The file to print the output into.
   -f, --format      The format of output.  Current options are:
                     'html' and 'text' (HTML not yet implemented)
   -l, --long-ouput  Print a LOC count for EVERY source file searched.
                     If you searched a big source tree, this could
                     create a very large amount of output!
   -d, --debug       Prints out a TON of debug messages, that really aren't
                     useful at all unless you're working on this script.
                     Seriously, I promise you won't like it.

More features will be implemented as the program matures.
(C) 2003 Ryan Joseph
Licensed under the GNU General Public License
HELP_TEXT

exit(0);
}

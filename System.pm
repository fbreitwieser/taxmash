use strict;
package System;
use IO::Uncompress::Gunzip qw/gunzip $GunzipError/;
use Term::ANSIColor;
use Exporter qw/import/;
use Carp qw/croak/;

our @EXPORT_OK = qw/sys isNewer print_eta/;


=head1 NAME

System - The great new System!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Colorful system calls that can be pretended, asked for, forced or verbosed.
To modify behaviour, set $System::pretend, etc, or the second argyment to
sys. Can capture output and only call when the output (or a check_file) does
not exist.

    use File::Basename; 
    use MyGetopt;
    use System qw/sys/;

    my ($opt, $usage) = MyGetopt::describe_options(
        basename($0)." <long-options> [arguments]",
        ["verbose", "Be verbose", {default=>1}],
        ["pretend", "Pretend system calls, only"],
        ["force", "Force system calls, even if file exists"],
        ["ask", "Ask before executing command", { default=>0}]
    );

    if (@ARGV == 0) { print $usage; exit 0; }

    $System::pretend = $opt->pretend;
    $System::verbose = $opt->verbose;
    $System::force = $opt->force;
    $System::ask = $opt->ask;

    # Capture STDOUT of command
    sys("ls", {output => "ls-results.txt", report_lines=>1});

=head1 EXPORT

sys

=head1 SUBROUTINES/METHODS

=head2 sys

=cut

our $pretend = 0;
our $force = 0;
our $ask = 0;
our $verbose = 0;
our $DIDNT_RUN = -1;
my $JUST_TOUCH_FILES = 0;

sub timestamp {
    my ($sec) = @_;
    use integer;
    my $res;
    if ($sec >= 60) {
        my $min = $sec / 60;
        $sec -= 60*$min;
        if ($min >= 60) {
            my $hour = $min / 60;
            $min -= 60*$hour;
            $res = $hour."h";
        }
        $res .= $min."m";
    }
    $res .= $sec."s";
    return $res;
}

my @eta_chars = qw#/ - \\ | / - \\ | #;
my $n_eta_chars = @eta_chars;
my $curr_eta_char = 0;

## print_eta usage:
#  my $fSize = -s $file;
#  open (my $F, "<", $file) or die $!;
#    my $n = 0; my $n0 = 0;
#    my $start_time = time;
#    while (<$F>) {
#      ...
#      if ($n0==100000) { print_eta(tell $MAP, $fSize, $start_time); $n0 = 0; } ++$n0; ++$n;
#   }
#   close($F);
sub print_eta {
    my ($pos, $fSize, $start_time) = @_;
    my $elapsed = time - $start_time;
    my $perc_finished = $pos/$fSize;
    my $total_time = $elapsed/$perc_finished;
    my $eta = $total_time - $elapsed;
    my $eta_date = timestamp(int($eta));
    my $run_date = timestamp($elapsed);
    $curr_eta_char = 0 if $curr_eta_char == $n_eta_chars;
    my $ram_usage = `ps -p $$ -h -o size | numfmt --to=iec --from-unit=K`;
    chomp $ram_usage;

    printf STDERR ("\r%s %.2f%%, running %s, ETA %s [RAM usage: %s]        ", 
        $eta_chars[$curr_eta_char++],
        100*$perc_finished, 
        $run_date,
        $eta_date,
        $ram_usage);
}


sub isNewer {
    my ($fileA, $fileB) = @_;
    return 0 unless -f $fileB && -f $fileA;
    ## -C gives 'age' of file
    #return -C $fileA < -C $fileB
    #return 0 if $DONT_CHECK_TIME;
    my $isNewer = ((stat($fileA))[9]) > ((stat($fileB))[9]);
    if ($isNewer && $JUST_TOUCH_FILES) {
        system_l("fix $fileB","touch $fileB");
        $isNewer = 0;
    }
    #print STDERR ($isNewer? "$fileA is newer than $fileB" : "$fileA is older than $fileB"),"\n";
    return $isNewer;
}

sub elapsed_time {
  my $t0 = shift;

  my $elapsed = time - $t0;
  my @elapsed;
  my $m = int($elapsed / 60); $elapsed -= 60*$m;
  my $h = int($m / 60); $m -= 60*$h;
  my $d = int($h / 24); $h -= 24*$d;
  my @res = "${elapsed}s";
  push @res, "${m}m" if ($m > 0);
  push @res, "${h}h" if ($h > 0);
  push @res, "${d}d" if ($d > 0);
  return join("",reverse @res);
}

sub system_l {
  my ($msg, $cmd, $opt) = @_;
  print STDERR $msg if defined $msg;
  my $t0 = time;
  my $exit_code = $DIDNT_RUN;
  print STDERR " [CMD ",colored($cmd, "yellow"),"] ... \n";
  if (!($opt->{pretend} // $System::pretend)) {
    if ($opt->{ask} // $System::ask) {
        print STDERR " Execute command? [yes (default), skip]:   ";
        my $res = <STDIN>; chomp $res;
        if ($res eq "yes" || $res eq "y") {
            # continue
        } elsif ($res eq "skip" || $res eq "s") {
            print STDERR "Skipping command execution.\n";
            return;
        } else {
            #print STDERR "Exiting.\n";
            #exit(1);
        }        
    }
    if ($opt->{bash}) {
        $exit_code = system("bash", "-c", $cmd);
    } else {
        $exit_code = system($cmd);
    }
    if ($exit_code != 0) {
        if ($opt->{die} // 1) {
            croak(colored("ERROR executing command: $! [Exit code $exit_code]\n", "red"));
        } else {
            print STDERR colored("ERROR executing command: $! [Exit code $exit_code]\n", "red");
        }
    }
  }

  print STDERR " done (took ",(elapsed_time($t0)),")\n";
  return $exit_code;
}

sub check_file {
    my $file = shift;
    my $size = (-s $file) / (1024*1024);
    printf STDERR "%-60s %10.2f Mb\n", colored($file, "green"), $size;
}

sub check_file_lines {
    my $file = shift;
    my $size = (-s $file) / (1024*1024);
    my $lines = `wc -l <$file`; chomp $lines;
    printf STDERR "%-60s $lines lines, %.2f Mb\n", colored($file, "green"), $size;
}

sub check_file_present {
    my $file = shift;
    printf STDERR "%s ✓\n", colored($file, "green");
}

## Possible options:
#   -verbose
#   -ask
#   -pretend
#   -force
#   -check_file    ## check if file exists - if it does, don't run
#   -prereq  ## check if prerequisite is newer - if it is, rerun
#   -check_size
#   -output
#   -message
sub sys {
  my ($cmd, $opt) = @_;
  defined $cmd or die "No command given";

  $opt = $opt // {};
  my $do_process = 1;
  if (defined $opt->{output}) {
    if (-f $opt->{output} && (!$opt->{check_size} || -s $opt->{output})) {
        if ($opt->{verbose} // $System::verbose) {
            if ($opt->{report_lines}) {
                check_file_lines($opt->{output}) if ($opt->{verbose} // $System::verbose);
            } else {
                check_file($opt->{output}) if ($opt->{verbose} // $System::verbose);
            }
        }
        $do_process = 0;
    } else {
        print STDERR $opt->{output}." does not exist or is empty.\n";
    }
  }
  if (defined $opt->{check_file}) {
    if (-f $opt->{check_file}) {
        check_file_present($opt->{check_file}) if ($opt->{verbose} // $System::verbose);
        #print STDERR "Not running command [".colored($cmd,"yellow")."] - $opt->{check_file} exists\n" if ($opt->{verbose} // $System::verbose);
        $do_process = 0;
    } else {
        print STDERR $opt->{check_file}." does not exist.\n";
    }
  }

  if (!$do_process && $opt->{prereq} && isNewer($opt->{prereq}, $opt->{output})) {
    print STDERR "$opt->{prereq} is newer than $opt->{output}";
    $do_process = 1;
  }

  if (!$do_process && ($opt->{force} // $System::force)) {
      $do_process = 1;
      print STDERR "Force running command.\n";
  }
  my $message = $opt->{msg};
  #$message = colored($opt->{output}, "blue") if (!defined $message && defined $opt->{output});
  #$message = colored($opt->{output}, "blue") if (!defined $message && defined $opt->{output});
  #$message = colored($opt->{check_file}, "magenta") if (!defined $message && defined $opt->{check_file});

  my $exit_code = $DIDNT_RUN;
  if ($do_process) {
    if ($opt->{output} && !$opt->{dont_capture_stdout}) {
        $cmd =~ s/%%%%/$opt->{output}/g;
        $exit_code = system_l($message, "$cmd > $opt->{output}.tmp && mv -v $opt->{output}.tmp $opt->{output}", $opt);
        check_file($opt->{output});
    } else {
        $exit_code = system_l($message, $cmd, $opt);
        system("date > $opt->{check_file}") if defined $opt->{check_file} && !$opt->{pretend} && !-f $opt->{check_file};
    }
  }
  my $res_f = $opt->{output} // $opt->{check_file};
  if ($do_process && $opt->{git} && $res_f) {
    system_l("Adding $res_f to git", "git add $res_f");
  }
  if (wantarray) {
      return ($res_f, $exit_code);
  } else {
      return $res_f;
  }
}


=head1 AUTHOR

Florian Breitwieser, C<< <florian.bw at gmail.com> >>

=cut

1;

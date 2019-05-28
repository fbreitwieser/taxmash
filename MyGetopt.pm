package MyGetopt;
use strict;
use warnings;

use Getopt::Long;
use Term::ANSIColor;
use Exporter qw/import/;
our @EXPORT = qw/describe_options/;

=head1 NAME

MyGetOpt - The great new MyGetOpt!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Produces options help page. Only works with long options for now. 
See Getopt::Long::Descriptive for a more feature-complete alternative.

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


=head1 EXPORT

describe_options

=head1 SUBROUTINES/METHODS

=head2 describe_options

=cut

my $usage = colored("script [options]","bold");
sub describe_options {
    my ($usage_desc, @opt_spec) = @_;

    my @gopts;
    my %options;
    my $short_options = "";
    my $has_long_options = 0;
    #my $usage = "\nOptions:";
    my $usage = "\n";
    foreach my $optt (@opt_spec) {
        next unless (scalar(@$optt) >= 2);

        push @gopts,$optt->[0];
        (my $optts = $optt->[0]) =~ s/[=!].*//;
        my $is_boolean = $optts eq $optt->[0];

        # Set default option
        my $opt_opt = $optt->[2] // {};
        $options{$optts} = $is_boolean && !defined $opt_opt->{default}? 0 : $opt_opt->{default};

        ## TODO: Suppport short options
        #foreach my $optts1 (split(/\|/, $optts) {
        #}

        if (!$opt_opt->{hidden}) {
            $usage .= sprintf("\t%-25s %s",
                colored("--".$optt->[0],"green"),
                colored($optt->[1],"reset"));

            if (defined $opt_opt->{default} || !$is_boolean) {
                $usage .= " ".colored("[default=".($opt_opt->{default} // '<undef>')."]","white");
            }
            $usage .= "\n";
        }
    }

    $usage = $usage_desc.$usage;

    GetOptions(\%options, @gopts) || die $usage;
    my $options_ref = \%options;
    bless($options_ref);
    return($options_ref, $usage);
}


=head1 AUTHOR

Florian Breitwieser, C<< <florian.bw at gmail.com> >>

=cut

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;

    # Remove qualifier from original method name...
    my $called =  $AUTOLOAD =~ s/.*:://r;

    #print STDERR "$called = $self->{$called}\n";
    # Is there an attribute of that name?
    die "No such attribute: $called"
        unless exists $self->{$called};

    # If so, return it...
    return $self->{$called};
}

sub DESTROY {}

1;

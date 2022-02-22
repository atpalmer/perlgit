#!/usr/bin/env perl

use strict;
use warnings FATAL => qw/all/;
use autodie;
use lib 'lib';
use GitObject;

my $cmd = Command::create(\@ARGV);
$cmd->(\@ARGV);


package Command {
    use Carp;

    sub create {
        my %COMMANDS = (
            'readobj' => \&readobj,
        );

        my ($argv) = @_;
        my $key = shift @$argv;
        my $cmd = $COMMANDS{$key};
        if (!defined($cmd)) {
            croak qq<'$key' is not a valid command. Valid commands are >
                . join(', ', map { qq('$_') } keys %COMMANDS);
        }
        return $cmd;
    }

    sub readobj {
        my ($argv) = @_;
        my $opts = Opts->parse($argv, 'path=s');
        my $object = GitObject->from_path($opts->{path});
        $object->say;
    }
}

package Opts {
    use Carp;
    use Getopt::Long qw/GetOptionsFromArray/;

    sub parse {
        my ($class, $argv, $config) = @_;
        my %opts = ();
        GetOptionsFromArray($argv, \%opts, $config) or die 'Bad Arguments';

        my %new;
        tie %new, $class, \%opts;
        return \%new;
    }

    sub TIEHASH {
        my $class = shift;
        my $new = shift;
        return bless $new, $class;
    }

    sub FETCH {
        my $self = shift;
        my $key = shift;
        croak qq<No option "$key"> if not defined $self->{$key};
        return $self->{$key};
    }
}

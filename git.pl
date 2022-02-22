#!/usr/bin/env perl

use strict;
use warnings FATAL => qw/all/;
use autodie;
use lib 'lib';
use GitObject;

my $opts = Opts->parse('path=s');

my $object = GitObject->from_path($opts->{path});

$object->say;


package Opts {
    use Getopt::Long;

    sub parse {
        my $class = shift;
        my $config = shift;
        my %opts = ();
        GetOptions(\%opts, $config) or die 'Bad Arguments';

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
        die qq<No option "$key"> if not defined $self->{$key};
        return $self->{$key};
    }
}

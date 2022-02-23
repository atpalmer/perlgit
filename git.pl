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
            'readhash' => \&readhash,
        );

        my ($argv) = @_;
        my $key = shift @$argv or croak 'Missing command';
        my $cmd = $COMMANDS{$key};
        if (!defined($cmd)) {
            croak qq<'$key' is not a valid command. Valid commands are (>
                . join(', ', map { qq('$_') } keys %COMMANDS) . ')';
        }
        return $cmd;
    }

    sub readobj {
        my ($argv) = @_;
        my $opts = Opts->parse($argv, 'path=s');
        my $object = GitObject->from_path($opts->{path});
        print $object->str;
    }

    sub readhash {
        my ($argv) = @_;
        my $opts = Opts->parse($argv, 'gitdir=s', 'hash=s');
        my $obpath = GitDir->from_path($opts->{gitdir})->object($opts->{hash});
        print qq(Reading object at "$obpath"\n);
        my $object = GitObject->from_path($obpath);
        print $object->str;
    }
}

package GitDir {
    use Carp;

    sub _ensure_valid_dir {
        my $path = shift;

        if (!-e $path) {
            croak "$path does not exist";
        }
        if (!-d $path) {
            croak "$path is not a directory";
        }

        return $path;
    }

    sub _ensure_valid_file {
        my $path = shift;

        if (!-e $path) {
            croak "$path does not exist";
        }
        if (!-f $path) {
            croak "$path is not a file";
        }

        return $path;
    }

    sub from_path {
        my ($class, $path) = @_;
        my $self = {
            git_dir => _ensure_valid_dir($path),
            ob_dir => _ensure_valid_dir("$path/objects"),
        };
        return bless $self, $class;
    }

    sub object {
        my ($self, $sha) = @_;
        my ($dir, $obfile) = $sha =~ /^([a-f0-9]{2})([a-f0-9]+)$/;
        if (!$obfile) {
            croak "$sha is not a valid hash";
        }
        return _ensure_valid_file(join '/', $self->{ob_dir}, $dir, $obfile);
    }
}

package Opts {
    use Carp;
    use Getopt::Long qw/GetOptionsFromArray/;

    sub parse {
        my $class = shift;
        my $argv = shift;
        my %opts = ();
        GetOptionsFromArray($argv, \%opts, @_) or die 'Bad Arguments';

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

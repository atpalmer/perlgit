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
            'headobj' => \&headobj,
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

    sub headobj {
        my ($argv) = @_;
        my $opts = Opts->parse($argv, 'gitdir=s');
        my $gitdir = GitDir->from_path($opts->{gitdir});
        my $reffile = FileReader::readline($gitdir->headfile);
        my $sha = $gitdir->follow_ref($reffile);
        my $obpath = $gitdir->object($sha);
        print qq(Reading object at "$obpath"\n);
        my $object = GitObject->from_path($obpath);
        print $object->str;
    }
}

package FileReader {
    use autodie;

    sub readline {
        my ($path) = @_;
        open my $f, '<', $path;
        my $line = <$f>;
        close $f;
        chomp $line;
        return $line;
    }
}

package GitDir {
    use Carp;

    sub _ensure_valid_dir {
        my ($path) = @_;

        if (!-e $path) {
            croak "$path does not exist";
        }
        if (!-d $path) {
            croak "$path is not a directory";
        }

        return $path;
    }

    sub _ensure_valid_file {
        my ($path) = @_;

        if (!-e $path) {
            croak "$path does not exist";
        }
        if (!-f $path) {
            croak "$path is not a file";
        }

        return $path;
    }

    sub _ensure_valid_sha {
        my ($sha) = @_;
        if ($sha !~ /^[a-f0-9]{40}$/) {
            croak "$sha is not a valid SHA";
        }
        return $sha;
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

    sub headfile {
        my ($self) = @_;
        return _ensure_valid_file(join '/', $self->{git_dir}, 'HEAD');
    }

    sub follow_ref {
        my ($self, $ref) = @_;
        while (my ($path) = $ref =~ /^ref: (.*)$/) {
            last if (!defined($path));
            $path = _ensure_valid_file(join '/', $self->{git_dir}, $path);
            print qq(Following ref to "$path"\n);
            $ref = FileReader::readline($path);
        }
        return _ensure_valid_sha($ref);
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

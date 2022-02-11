#!/usr/bin/env perl

use strict;
use warnings FATAL => qw/all/;
use autodie;
use lib 'lib';
use GitObject;

my $path = shift or die;

my $object = GitObject->from_path($path);

$object->say;


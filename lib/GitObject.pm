use strict;
use warnings FATAL => qw/all/;
use autodie;
use feature qw/say/;
use GitFile;


package Util;

sub say_hash {
    my $hashref = shift;
    my $keyref = shift;
    for my $k (@$keyref) {
        my $v = $hashref->{$k};
        say "$k: $v";
    }
}


package GitObject;

sub _parse_base {
    my $raw = shift;
    my ($header, $payload) = $raw =~ /^(.*?)\0(.*)/s;
    my ($type, $size) = split ' ', $header;

    my $object = {
        raw => $raw,
        header => $header,
        payload => $payload,
        type => $type,
        size => $size,
    };

    return $object;
}

sub from_raw {
    my $class = shift;
    my $raw = shift;

    my $object = _parse_base($raw);

    if ($object->{type} eq 'commit') {
        return GitCommitObject->from_base($object);
    } elsif ($object->{type} eq 'tree') {
        return GitTreeObject->from_base($object);
    } elsif ($object->{type} eq 'blob') {
        return GitBlobObject->from_base($object);
    } elsif ($object->{type} eq 'tag') {
        return GitTreeObject->from_base($object);
    }

    warn('Unknown object type: ', $object->type);

    return bless $object, $class;
}

sub from_path {
    my $class = shift;
    my $path = shift;
    my $raw = GitFile::read_zfile($path);
    return $class->from_raw($raw);
}

sub say {
    my $self = shift;
    Util::say_hash($self, ['type', 'size']);
}


package GitCommitObject;

sub _parse_payload{
    my $dataref = shift or die;

    my %commit;
    open my $h, '<', $dataref;

    for (;;) {
        $_ = <$h>;
        chomp;
        last if ($_ eq '');
        my ($k, $v) = split ' ', $_, 2;
        $commit{$k} = $v;
    }

    $commit{body} = join '', <$h>;
    close $h;

    return \%commit;
}

sub from_base {
    my $class = shift;
    my $object = shift;
    die if $object->{type} ne 'commit';

    $object->{commit} = _parse_payload(\$object->{payload});

    return bless $object, $class;
}

sub say {
    my $self = shift;
    GitObject::say($self);
    Util::say_hash($self->{commit}, ['tree', 'parent', 'author', 'committer', 'body']);
}


package GitTreeObject;

sub _parse_payload {
    my $dataref = shift;
    my $data = $$dataref;
    my @objects;

    while ($data ne '') {
        my ($mode, $name, $rawhash, $rest) = $data =~ /^(.*?) (.*?)\0(.{20})(.*)$/;

        my $hash = join '',
            map { sprintf('%02x', $_) }
            unpack('CCCCCCCCCCCCCCCCCCCC', $rawhash);

        my %object = (
            mode => $mode,
            name => $name,
            hash => $hash,
        );

        push @objects, \%object;

        $data = $rest;
    }

    return \@objects;
}

sub from_base {
    my $class = shift;
    my $object = shift;
    die if $object->{type} ne 'tree';

    $object->{objects} = _parse_payload(\$object->{payload});

    return bless $object, $class;
}

sub say {
    my $self = shift;
    GitObject::say($self);
    for my $objref (@{$self->{objects}}) {
        say 'object ref:';
        Util::say_hash($objref, ['mode', 'name', 'hash']);
    }
}


package GitBlobObject;

sub from_base {
    my $class = shift;
    my $object = shift;
    die if $object->{type} ne 'blob';

    return bless $object, $class;
}

sub say {
    my $self = shift;
    GitObject::say($self);
    say $self->{payload};
}

1;

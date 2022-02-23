use strict;
use warnings FATAL => qw/all/;
use autodie;
use feature qw/say/;
use GitFile;

package Util {
    sub str_hash {
        my $hashref = shift;
        my $keyref = shift;
        return join '', map {
            "$_: " . $hashref->{$_} . "\n";
        } @$keyref;
    }
}

package GitObject {
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

    my %OBTYPE_INIT = (
        'commit' => \&GitCommitObject::from_base,
        'tree' => \&GitTreeObject::from_base,
        'blob' => \&GitBlobObject::from_base,
        'tag' => \&GitTagObject::from_base,
    );

    sub from_raw {
        my $class = shift;
        my $raw = shift;

        my $object = _parse_base($raw);

        my $init = $OBTYPE_INIT{$object->{type}};

        if (!defined($init)) {
            warn('Unknown object type: ', $object->type);
            return bless $object, $class;
        }

        return $init->($object);
    }

    sub from_path {
        my $class = shift;
        my $path = shift;
        my $raw = GitFile::read_zfile($path);
        return $class->from_raw($raw);
    }

    sub str {
        my $self = shift;
        return Util::str_hash($self, ['type', 'size']);
    }
}

package GitCommitObject {
    use Carp;

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
        my $object = shift;
        croak if $object->{type} ne 'commit';
        $object->{commit} = _parse_payload(\$object->{payload});
        return bless $object;
    }

    sub str {
        my $self = shift;
        return GitObject::str($self)
            . Util::str_hash($self->{commit}, ['tree', 'parent', 'author', 'committer', 'body']);
    }
}


package GitTreeObject {
    use Carp;

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
        my $object = shift;
        croak if $object->{type} ne 'tree';
        $object->{objects} = _parse_payload(\$object->{payload});
        return bless $object;
    }

    sub str {
        my $self = shift;
        return GitObject::str($self)
            .  join '', map { "object ref:\n" .  Util::str_hash($_, ['mode', 'name', 'hash']) } @{$self->{objects}};
    }
}

package GitBlobObject {
    use Carp;

    sub from_base {
        my $object = shift;
        croak if $object->{type} ne 'blob';
        return bless $object;
    }

    sub str {
        my $self = shift;
        return GitObject::str($self) . $self->{payload};
    }
}

1;

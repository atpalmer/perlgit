use strict;
use warnings FATAL => qw/all/;

package GitFile;
use autodie;

use Compress::Zlib;

sub read_zfile {
    my $path = shift;
    my $data = read_binary_file($path);
    return z_inflate($data);
}

sub z_inflate {
    my $data = shift;
    my ($i, $status, $result);

    ($i, $status) = inflateInit();
    die if $status != Z_OK;

    ($result, $status) = $i->inflate($data);
    die $status if $status != Z_STREAM_END;

    return $result;
}

sub read_binary_file {
    my $path = shift;
    open my $f, '<', $path;
    binmode $f;
    local($/);
    my ($data) = <$f>;
    close $f;
    return $data;
}

1;

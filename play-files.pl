#!/usr/bin/env perl 

# play-files.pl
#
# Sorts a list of Ogg Vorbis files and runs mplayer on the sorted list.

use strict;
use warnings;
use feature 'state';

use Ogg::Vorbis::Header;

sub get_info
{
    my $file = shift;
    state %cache;

    unless(exists $cache{$file}) {
        my $info = $cache{$file} = [];
        my $ogg = Ogg::Vorbis::Header->new($file);

        my @values = $ogg->comment('album');
        @values = $ogg->comment('ALBUM') unless @values && defined($values[0]);
        unless(@values && defined($values[0])) {
            warn "album not defined for $file\n";
        }
        $info->[0] = $values[0];
        @values = $ogg->comment('tracknumber');
        @values = $ogg->comment('TRACKNUMBER') unless @values && defined($values[0]);
        unless(@values && defined($values[0])) {
            warn "tracknumber not defined for $file\n";
        }
        $info->[1] = $values[0];
        $info->[1] =~ s!/\d+$!!g; # handle $num/$total
    }
    return @{$cache{$file}};
}

my @files = @ARGV;

@files = sort {
    my ($a_album, $a_num) = get_info($a);
    my ($b_album, $b_num) = get_info($b);

    if($a_album ne $b_album) {
        $a_album cmp $b_album
    } else {
        $a_num <=> $b_num
    }
} @files;

exec 'mplayer', @files;

#!/usr/bin/env perl

use strict;
use warnings;
use autodie;
use feature qw(say);

use File::Spec;

open my $pipe, 'vim -r 2>&1 |';

# Example: '   In directory ~/.vim/swaps/:'
my $directory_re = qr{
    ^
    \s*
    In \s+ directory \s+
    (?<directory>.*)
    :
    \s*
    $
}x;

# Example: '1.    DiffIt.pm.swp'
my $filename_re = qr{
    ^
    \d+
    [.]
    \s+
    (?<filename>.*?) # non-greedy so that the following \s* rule can trim EOL WS
    \s*
    $
}x;

# Examples: '        process ID: 719'
#           '        process ID: 7608 (still running)'
my $pid_re = qr{
    ^
    (?> # disable backtracking so that the negative lookahead
        # below can't just back up to force a match
        \s*
        process \s+ ID:
        \s+ \d+ \s*
    )
    (?!
        \(
        still \s+ running
        \)
    )
}x;

my $swap_directory;
my $swap_filename;

while(<$pipe>) {
    chomp;

    if(/$directory_re/) {
        $swap_directory = $+{'directory'};
    } elsif(/$filename_re/) {
        $swap_filename = $+{'filename'};
    } elsif(/$pid_re/) {
        say File::Spec->catfile($swap_directory, $swap_filename);
    }
}
close $pipe;

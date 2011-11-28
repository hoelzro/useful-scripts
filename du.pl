#!/usr/bin/env perl

# du.pl - List the files (hidden and non-hidden) in the provided directory
#         (or the current directory if none is provided) and displays them,
#         sorted by size.

use autodie qw(fork opendir pipe);
use strict;
use warnings;
use 5.10.0; # for defined-or

my ( $dir ) = @ARGV;
$dir //= '.';

my $dh;
opendir $dh, $dir;
my @files = readdir $dh;
@files = grep { !/^\.\.?$/ } @files;
closedir $dh;

my ( $read, $write );
pipe $read, $write;

my $pid = fork;

if($pid) {
    close $read;
    open STDOUT, '>&', $write;
    close STDIN;
    exec 'du', '-hs', @files;
} else {
    close $write;
    open STDIN, '<&', $read;
    exec 'sort', '-h';
}

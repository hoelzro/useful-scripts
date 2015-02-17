#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(say);

# Terminal theme loader
#
# Loads themes from https://github.com/stayradiated/terminal.sexy for easier
# testing

use File::Slurp qw(read_file);
use JSON qw(decode_json);
use Term::ANSIColor;

my @COLORS = qw(black white blue red green yellow magenta cyan);

sub print_color_grid {
    for my $fg_color (@COLORS) {
        say join(' ', map { colored(["$fg_color on_$_"], "$fg_color on $_") } @COLORS);
    }
}

sub load_colors {
    my ( $filename ) = @_;

    my $payload = decode_json(scalar(read_file($filename)));

    return map { uc() } ( @{$payload}{qw/foreground background foreground/}, @{ $payload->{'color'} } );
}

sub alter_colors {
    my ( $fg, $bg, $cursor, @rest ) = @_;

    local $| = 1;
    print "\e]10;$fg\a";
    print "\e]11;$bg\a";
    print "\e]12;$cursor\a";

    for my $i (0 .. $#rest) {
        my $value = $rest[$i];

        print "\e]4;$i;$value\a";
    }
}

die "usage: $0 [scheme.json]\n" unless @ARGV;

my @new_color_values = load_colors($ARGV[0]);

alter_colors(@new_color_values);
print_color_grid();

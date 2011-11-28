#!/usr/bin/env perl

# decolorize.pl - Remove ANSI terminal coloration codes from the output
#                 of programs to dumb to it themselves

use strict;
use warnings;

while(<>) {
    s/\033\[[^m]+m//g;
    print;
}

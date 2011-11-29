#!/usr/bin/env perl

# utf8tocp.pl - Converts a series of UTF-8 encoded octets to a Unicode
#               codepoint and outputs it.
#
# Example: utf8tocp.pl c3 b3
# 0xf3 - ó

use strict;
use warnings;
use feature 'say';

use Encode;

my ( @pieces ) = @ARGV;

my $buffer = pack('C*', map { hex($_) } @pieces);
   $buffer = decode_utf8($buffer);
binmode STDOUT, ':encoding(utf8)';
say sprintf('0x%x', ord($buffer)), ' - ', $buffer;

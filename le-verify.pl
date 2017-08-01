#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use utf8::all;

use List::Util qw(max);

sub get_current_values {
    my @domains = @_;
    my @values;

    for my $domain (@domains) {
        my $value = qx(dig @8.8.8.8 +short _acme-challenge.$domain TXT);
        chomp $value;
        $value =~ s/"//g;
        push @values, $value;
    }

    return @values;
}

my @domains_and_values;

while(<>) {
    chomp;
    if(/_acme-challenge[.](?<domain>\S+)\s*IN TXT  "(?<value>[^"]+)"/) {
        push @domains_and_values, [ @+{qw/domain value/} ];
    }
}

my $num_matching = 0;

my $format = '%' . max(map { length($_->[0]) } @domains_and_values) . "s %s\n";

while($num_matching < @domains_and_values) {
    my @current_values = get_current_values(map { $_->[0] } @domains_and_values);

    $num_matching = 0;
    for my $i (0..$#domains_and_values) {
        my ( $domain, $expected_value ) = @{ $domains_and_values[$i] };
        my $got_value = $current_values[$i];

        my $prefix;

        if($expected_value eq $got_value) {
            $num_matching++;
            $prefix = "\e[32;1m✓\e[0m";
        } else {
            $prefix = "\e[31;1mX\e[0m";
        }
        printf "$prefix $format", $domain, $got_value;
    }
    say '';

    sleep 60;
}

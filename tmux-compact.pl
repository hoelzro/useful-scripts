#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';

my $last_index;
my $active_window;
my @windows = qx(tmux list-windows -F '#{window_active} #{window_index}');

foreach my $line (@windows) {
    chomp $line;
    $line =~ /^(?<is_active>0|1)\s+(?<index>\d+)$/;

    if($+{'is_active'}) {
        $active_window = $+{'index'};
    }
    $line = $+{'index'};
}

foreach my $index (@windows) {
    if(! defined($last_index)) {
        $last_index = $index;
    } else {
        if($index - 1 != $last_index) {
            system 'tmux', 'move-window', '-s', ":$index", '-t',
                ':' . ( $last_index + 1);
            if($index == $active_window) {
                $active_window = $last_index + 1;
            }
            $index = $last_index + 1;
        }

        $last_index = $index;
    }
}

system 'tmux', 'select-window', '-t', ":$active_window";

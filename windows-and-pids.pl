#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use experimental qw(signatures);

use File::Slurper qw(read_binary);
use File::stat;

sub find_depth($tuple, $other_procs) {
    my ( undef, $ppid ) = @$tuple;

    my ( $match ) = grep { $_->[0] == $ppid } @$other_procs;

    if($match) {
        return 1 + find_depth($match, $other_procs);
    } else {
        return 1;
    }
}

my %window_to_pids;

for my $proc_dir (glob('/proc/*/')) {
    next unless $proc_dir =~ m{^/proc/\d+/};

    my $stat = stat($proc_dir);

    next unless $stat;
    next unless $stat->uid == $>;

    my $cmd_line;
    my $pid;
    my $state;
    my $ppid;
    my $environ;

    eval {
        # XXX better name?
        my $stat = read_binary("$proc_dir/stat");

        ( $pid, $state, $ppid ) = $stat =~ m{^(\d+)\s+\(.*?\)\s+(.)\s+(\d+)};

        $cmd_line = read_binary("$proc_dir/cmdline");
        $environ = read_binary("$proc_dir/environ");

        1
    } or do {
        next; # XXX don't fail on read_binary I/O only?
    };

    next if $state eq 'Z';

    my %environ;

    while($environ =~ /(.*?)=(.*?)\0/g) {
        $environ{$1} = $2;
    }

    my $wd = readlink("$proc_dir/cwd");

    if(my $window_id = $environ{'WINDOWID'}) {
        $cmd_line =~ s/\0/ /g;
        push @{ $window_to_pids{ $window_id } }, [ $pid, $ppid, $cmd_line, $wd ];
    }
}

open my $pipe, '-|', 'wmctrl -l -x';
while(<$pipe>) {
    chomp;
    my ( $hex_window_id ) = /^(0x[[:xdigit:]]+)/;
    my $window_id = hex($hex_window_id);

    say;

    if(my $pids_using_window = $window_to_pids{$window_id}) {
        # fix sort order
        # sort by pid, extract all top-level pids, while(@$pids) { if($ppid in new list) { add right after $ppid } assert decreasing in size }
        @$pids_using_window = sort {
            my ( $a_pid, $a_ppid ) = @$a;
            my ( $b_pid, $b_ppid ) = @$b;

            $a_ppid == $b_pid
                ? 1
                : ($b_ppid == $a_pid ? -1 : $a_pid <=> $b_pid)
        } @$pids_using_window;

        for my $tuple (@$pids_using_window) {
            my ( $pid, $ppid, $cmd, $wd ) = @$tuple;

            my $depth = find_depth($tuple, $pids_using_window);

            say '  ' x $depth, join("\t", $pid, $cmd, $wd);
        }
    }
}
close $pipe;

# I could've sworn I needed root...but maybe I don't?
# window groups like claws-mail

#!/usr/bin/env perl

my $my_start_time;

BEGIN { $my_start_time = time }

use autodie;
use strict;
use warnings;
use feature qw(say);
use experimental qw(signatures);

use Cwd ();
use File::Spec;
use File::stat;
use File::Slurper qw(read_dir read_lines);
use List::Util qw(sum);
use Number::Format qw(format_bytes);
use POSIX qw(sysconf _SC_CLK_TCK);

sub read_command_line($pid) {
    my ( $line ) = read_lines("/proc/$pid/cmdline");

    return split /\0/, $line;
}

sub find_arguments(@command_line) {
    my $command = shift @command_line;
    # XXX maybe just read `file $command`?
    if($command =~ /python/ || $command =~ /perl/) {
        shift @command_line;
    }
    return @command_line;
}

sub cumsum(@values) {
    my @result;
    my $sum = 0;

    for my $value (@values) {
        $sum += $value;
        push @result, $sum;
    }
    return @result;
}

sub process_is_running($pid) {
    no autodie 'kill';

    return kill 0, $pid;
}

sub find_current_work_file($pid, @arg_files) {
    my $index = 0;
    my %arg_files = map { $_ => $index++ } @arg_files;
    my @files = read_dir("/proc/$pid/fd");

    for my $fd (@files) {
        my $path = File::Spec->catfile("/proc/$pid/fd", $fd);
        my $target = readlink($path);
        if(exists $arg_files{$target}) {
            return ( $fd, $arg_files{$target} );
        }
    }
    return;
}

sub read_progress($pid, $fd) {
    my @lines = read_lines( "/proc/$pid/fdinfo/$fd");
    for my $line (@lines) {
        chomp $line;
        if($line =~ /^pos:\s*(\d+)/) {
            return $1;
        }
    }
    return;
}

sub read_proc_start_time($pid) {
    open my $fh, '<', "/proc/$pid/comm";
    my $comm = <$fh>;
    chomp $comm;
    close $fh;

    open $fh, '<', "/proc/$pid/stat";
    my $line = <$fh>;
    close $fh;

    chomp $line;
    $comm = quotemeta($comm);
    $line =~ s/\($comm\)/placeholder/;
    my @fields = split /\s+/, $line;

    my $start_time_in_clock_ticks = $fields[21];

    return $start_time_in_clock_ticks;
}

sub find_process_start_time($pid) {
    my $my_clock_ticks   = read_proc_start_time($$);
    my $pid_clock_ticks  = read_proc_start_time($pid);
    my $ticks_per_second = sysconf(_SC_CLK_TCK);

    return do { use integer; $my_start_time + ($pid_clock_ticks - $my_clock_ticks) / $ticks_per_second };
}

sub find_working_directory($pid) {
    return readlink("/proc/$pid/cwd");
}

die "Usage: $0 [pid]\n" unless @ARGV;

my ( $pid ) = @ARGV;

my @command_line = read_command_line($pid);
my $wd = find_working_directory($pid);
my @args = find_arguments(@command_line);
@args = map { Cwd::realpath(File::Spec->rel2abs($_, $wd)) } @args;
my @arg_sizes = map { -s } @args;
my @cum_sizes = cumsum(@arg_sizes);
my $total = $cum_sizes[-1];

my $start_time = find_process_start_time($pid);

do {
    local $| = 1;
    print "\e[s";
};

while(process_is_running($pid)) {
    my ( $fd, $currently_working_on ) = find_current_work_file($pid, @args);
    # XXX handle error
    my $preceding_args_size = $currently_working_on == 0 ? 0 : $cum_sizes[$currently_working_on - 1];
    my $current_file_progress = read_progress($pid, $fd);
    # XXX handle error
    my $total_progress = $preceding_args_size + $current_file_progress;
    my $remaining = $total - $total_progress;
    my $time_taken = time - $start_time;
    my $rate = $total_progress / $time_taken;

    my $time_remaining = $remaining / $rate;
    my $time_left = '';
    if($time_remaining > 3_600) {
        use integer;
        $time_left .= ($time_remaining / 3_600) . 'h';
        $time_remaining %= 3_600;
    }

    if($time_remaining > 60) {
        use integer;
        $time_left .= ($time_remaining / 60) . 'm';
        $time_remaining %= 60;
    }
    $time_left .= sprintf('%ds', $time_remaining);

    do {
        local $| = 1;
        my $percent_complete = sprintf('%.2f%%', 100 * $total_progress / $total);
        print "\e[u\e[2K$percent_complete ETA: $time_left";
    };

    sleep 1;
}

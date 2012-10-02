#!/usr/bin/env perl

use 5.14.0;
use autodie;
use warnings;

use File::Which;
use MP3::Tag;

sub convert_to_ogg {
    my ( $mp3, $ogg, %metadata ) = @_;

    my ( $read, $write );

    pipe($read, $write);

    my $mp3_pid = fork();

    if($mp3_pid) {
        close $write;
        my $ogg_pid = fork();

        if($ogg_pid) {
            waitpid(-1, 0);
            waitpid(-1, 0);
        } else {
            close STDOUT;
            close STDERR;
            open STDIN, '<&', $read;

            exec 'oggenc', '-o', $ogg,
                '-a', $metadata{'artist'},
                '-G', $metadata{'genre'},
                '-d', $metadata{'year'},
                '-N', $metadata{'track'},
                '-t', $metadata{'title'},
                '-l', $metadata{'album'},
                '-';
        }
    } else {
        close $read;
        open STDOUT, '>&', $write;
        close STDERR;
        close STDIN;
        exec 'lame', '--decode', $mp3, '-';
    }
}

# XXX check for required programs

die "usage: $0 [file.mp3]\n" unless @ARGV;

my ( $input ) = @ARGV;
my $mp3       = MP3::Tag->new($input);

my ( $title,
     $track,
     $artist,
     $album,
     $comment,
     $year,
     $genre ) = $mp3->autoinfo();

my $output = $input =~ s/[.]mp3$/.ogg/r;

if(-f $output) {
    die "'$output' already exists\n";
}

$track =~ s{/\d+}{};

convert_to_ogg($input, $output,
    title   => $title,
    track   => $track,
    artist  => $artist,
    album   => $album,
    year    => $year,
    genre   => $genre,
    comment => $comment,
);

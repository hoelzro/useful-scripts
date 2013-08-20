#!/usr/bin/env perl

use 5.14.0;
use autodie;
use warnings;

sub convert_to_ogg {
    my ( $input, $ogg, %metadata ) = @_;

    my ( $read, $write );

    pipe($read, $write);

    my $input_pid = fork();

    if($input_pid) {
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

        if($input =~ /[.]mp3$/) {
            exec 'lame', '--decode', $input, '-';
        } else {
            exec 'flac', '--decode', '--silent', '--stdout', $input;
        }
    }
}

# XXX check for required programs

die "usage: $0 [file.mp3]\n" unless @ARGV;

my ( $input ) = @ARGV;
my $output;

my ( $title, $track, $artist, $album, $comment, $year, $genre );

if($input =~ /[.]mp3$/) {
    require MP3::Tag;

    my $mp3 = MP3::Tag->new($input);

    ( $title,
         $track,
         $artist,
         $album,
         $comment,
         $year,
         $genre ) = $mp3->autoinfo();
    $output = $input =~ s/[.]mp3$/.ogg/r;
} elsif($input =~ /[.]flac$/) {
    require Audio::FLAC::Header;

    my $flac = Audio::FLAC::Header->new($input);
    my $tags = $flac->tags;

    ( $title,
         $track,
         $artist,
         $album,
         $comment,
         $year,
         $genre ) = @{$tags}{qw/TITLE TRACKNUMBER ARTIST ALBUM COMMENT DATE GENRE/};

    $output = $input =~ s/[.]flac$/.ogg/r;
} else {
    die "Unrecognized file type for input '$input'\n";
}

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

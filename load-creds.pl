#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use experimental qw(signatures);

use File::KeePass;
use Term::ReadPassword qw(read_password);

sub split_path($path) {
    return split(qr{/}, $path)
}

sub find_entry($group, @path) {
    if(@path > 1) {
        my $group_name = shift @path;
        for my $g (@{ $group->{'groups'} }) {
            if($g->{'title'} eq $group_name) {
                return find_entry($g, @path);
            }
        }
    } else {
        my ( $entry_name ) = @path;

        for my $entry (@{ $group->{'entries'} }) {
            if($entry->{'title'} eq $entry_name) {
                return $entry;
            }
        }
        die "Unable to find entry";
    }
}

sub list_entries($group, $indent=-1) {
    if(my $name = $group->{'title'}) {
        say '  ' x $indent, "$name/";
    }

    my @children = (
        (map { [1, $_] } @{ $group->{'groups'} }),
        (map { [0, $_] } @{ $group->{'entries'} }));

    @children = sort { $a->[1]{'title'} cmp $b->[1]{'title'} } @children;

    for my $pair (@children) {
        my ( $is_group, $child ) = @$pair;

        next if $is_group && $child->{'title'} eq 'Backup';

        if($is_group) {
            list_entries($child, $indent + 1);
        } else {
            next if $child->{'title'} eq 'Meta-Info';

            say '  ' x ($indent + 1), $child->{'title'};
        }
    }
}

my $filename = $ENV{'CRED_DB'};

my ( $path ) = @ARGV;

my $password = read_password("Password for '$filename': ");
my $kdb = File::KeePass->new;
$kdb->load_db($filename, $password);
$kdb->unlock;

if($path) {
    my $entry = find_entry({ groups => $kdb->groups }, split_path($path));

    my @comment_lines = split /\n/, $entry->{'comment'};

    say "export $_" for @comment_lines;
} else {
    list_entries({ groups => $kdb->groups });
}

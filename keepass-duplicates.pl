#!/usr/bin/env perl

# keepass-duplicates.pl - Prints entries that share passwords in a Keepass
#                         password file.

use strict;
use warnings;
use feature 'say';

use File::KeePass;
use Term::ReadPassword;

die "usage: $0 [keepass DB]\n" unless @ARGV;
my ( $filename ) = @ARGV;

my $kdb = File::KeePass->new;
my $password = read_password("Password for '$filename': "); 
$kdb->load_db($filename, $password);
$kdb->unlock;

my %passwords;

foreach my $group (@{ $kdb->groups }) {
    next if $group->{'title'} eq 'Backup';
    foreach my $entry (@{ $group->{'entries'} }) {
        my $entry_name = $entry->{'title'};
        my $password   = $entry->{'password'};
        push @{ $passwords{$password} ||= [] }, $entry_name;
    }
}

my @has_duplicate;
foreach my $entries (values %passwords) {
    next unless @$entries > 1;
    push @has_duplicate, @$entries;
}

say foreach sort @has_duplicate;

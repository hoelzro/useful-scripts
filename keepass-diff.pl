#!/usr/bin/env perl

# keepass-diff.pl - Diffs two Keepass password files.

use strict;
use warnings;
use feature 'say';

use Digest;
use File::KeePass;
use Term::ReadPassword;
use Time::Piece;

my $DATETIME_FORMAT = '%Y-%m-%d %H:%M:%S';

sub sha1 {
    my ( $filename ) = @_;

    my $digest = Digest->new('SHA1');
    open my $fh, '<', $filename or die $!;
    $digest->addfile($fh);

    close $fh;

    return $digest->hexdigest;
}

sub flatten_groups {
    my ( $groups, @prefix ) = @_;

    return map { $_->{'title'} = join('.', @prefix, $_->{'title'}); ($_, flatten_groups($_->{'groups'}, @prefix, $_->{'title'})) } @$groups;
}

die "usage: $0 [old] [new]\n" unless @ARGV >= 2;
my ( $old_filename, $new_filename ) = @ARGV;
die "File '$old_filename' does not exist\n" unless -e $old_filename;
die "File '$new_filename' does not exist\n" unless -e $new_filename;

my $password = read_password("Password for '$old_filename': ");
my $old = File::KeePass->new;
$old->load_db($old_filename, $password);
$old->unlock;
my $new = File::KeePass->new;
eval {
    $new->load_db($new_filename, $password);
    $new->unlock;
};
if($@) {
    $password = read_password("Password for '$new_filename': ");
    $new->load_db($new_filename, $password);
    $new->unlock;
}

my @old_groups = flatten_groups $old->groups;
my @new_groups = flatten_groups $new->groups;
my $i = 0;
my %old_group_names = map { $_->{'title'} => $i++ } @old_groups;
$i = 0;
my %new_group_names = map { $_->{'title'} => $i++ } @new_groups;

my $difference_count = 0;

foreach my $k (sort keys %old_group_names) {
    unless(exists $new_group_names{$k}) {
        say "Group '$k' exists in $old_filename, but not $new_filename";
        $difference_count++;
    }
}

foreach my $k (sort keys %new_group_names) {
    unless(exists $old_group_names{$k}) {
        say "Group '$k' exists in $new_filename, but not $old_filename";
        $difference_count++;
    }
}

foreach my $group (sort keys %old_group_names) {
    next unless exists $new_group_names{$group};
    next if $group eq 'Backup';

    my $group_printed;

    my $old_group = $old_groups[$old_group_names{$group}];
    my $new_group = $new_groups[$new_group_names{$group}];
    my @old_entries = sort { $a->{'title'} cmp $b->{'title'} } @{ $old_group->{'entries'} };
    my @new_entries = sort { $a->{'title'} cmp $b->{'title'} } @{ $new_group->{'entries'} };

    $i = 0;
    my %old_names = map { $_->{'title'} => $i++ } @old_entries;
    $i = 0;
    my %new_names = map { $_->{'title'} => $i++ } @new_entries;

    foreach my $name (sort keys %old_names) {
        unless(exists $new_names{$name}) {
            unless($group_printed) {
                say $group, ':';
                $group_printed = 1;
            }
            say "  Entry '$name' exists in $old_filename, but not $new_filename";
            $difference_count++;
        }
    }

    foreach my $name (sort keys %new_names) {
        unless(exists $old_names{$name}) {
            unless($group_printed) {
                say $group, ':';
                $group_printed = 1;
            }
            say "  Entry '$name' exists in $new_filename, but not $old_filename";
            $difference_count++;
        }
    }

    foreach my $old_entry (@old_entries) {
        next unless exists $new_names{$old_entry->{'title'}};

        my $new_entry = $new_entries[$new_names{$old_entry->{'title'}}];

        my $matches = $old_entry->{'password'} eq $new_entry->{'password'} &&
                      $old_entry->{'comment'}  eq $new_entry->{'comment'}  &&
                      $old_entry->{'username'} eq $new_entry->{'username'} &&
                      $old_entry->{'url'}      eq $new_entry->{'url'};

        unless($matches) {
            unless($group_printed) {
                say $group, ':';
                $group_printed = 1;
            }
            my $old_time = Time::Piece->strptime($old_entry->{'modified'}, $DATETIME_FORMAT);
            my $new_time = Time::Piece->strptime($new_entry->{'modified'}, $DATETIME_FORMAT);

            my $newer = $old_time < $new_time ? $new_filename : $old_filename;
            say "  Entry '$old_entry->{'title'}' has two different contents ($newer is newer)";
            $difference_count++;
        }
    }
}

if($difference_count == 0) {
    my $old_checksum = sha1($old_filename);
    my $new_checksum = sha1($new_filename);

    if($old_checksum ne $new_checksum) {
        say "There were no detected differences in the entries, but the files are different.  That's odd...";
    }
}

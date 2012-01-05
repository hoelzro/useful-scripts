#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';

use File::Spec;
use DBI;
use JSON;

my $db_path = File::Spec->catfile($ENV{'HOME'}, '.config', 'chromium',
    'Default', 'Web Data');

my $contents = do {
    local $/;
    <>;
};

my $json = JSON->new->utf8;
my $rows = $json->decode($contents);

my $dbh = DBI->connect('dbi:SQLite:dbname=' . $db_path, undef, undef, {
    PrintError => 0,
    RaiseError => 1,
});

my $first_row = $rows->[0];
my @columns   = keys %{$first_row};
my $sql       = 'INSERT INTO keywords (' . join(', ', @columns) . ') VALUES ('
              . join(', ', map { '?' } @columns) . ')';

my $insert_sth = $dbh->prepare($sql);
my $lookup_sth = $dbh->prepare('SELECT COUNT(1) FROM keywords WHERE keyword = ?');

$dbh->begin_work;
foreach my $row (@{$rows}) {
    $lookup_sth->execute($row->{'keyword'});
    my ( $count ) = $lookup_sth->fetchrow_array;
    unless($count) {
        $insert_sth->execute(@{$row}{@columns});
    }
}
$dbh->commit;

$dbh->disconnect;

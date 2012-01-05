#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';

use File::Copy;
use File::Spec;
use File::Temp;
use DBI;
use JSON;
use Readonly;

Readonly::Scalar my $SQLITE_BUSY   => 5;
Readonly::Scalar my $SQLITE_LOCKED => 6;

sub db_connect {
    my ( $path ) = @_;

    my $dbh = DBI->connect('dbi:SQLite:dbname=' . $path, undef, undef, {
        PrintError => 0,
    });

    my ( $count ) = $dbh->selectrow_array('SELECT COUNT(1) FROM keywords');

    if($dbh->err == $SQLITE_LOCKED || $dbh->err == $SQLITE_BUSY) {
        my $tempfile = File::Temp->new();
        close $tempfile;

        copy($path, $tempfile->filename) or die $!;

        return DBI->connect('dbi:SQLite:dbname=' . $tempfile->filename, undef, undef, {
            PrintError => 0,
            RaiseError => 1,
        });
    } else {
        $dbh->{'RaiseError'} = 1;
        return $dbh;
    }
}

my $db_path = File::Spec->catfile($ENV{'HOME'}, '.config', 'chromium',
    'Default', 'Web Data');

my $dbh = db_connect($db_path);

my $rows = $dbh->selectall_arrayref(<<'END_SQL', { Slice => {} });
SELECT * FROM keywords WHERE keyword NOT LIKE '%.%'
END_SQL

my $json = JSON->new->utf8->pretty(1);
print $json->encode($rows);

$dbh->disconnect;

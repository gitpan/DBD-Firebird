#!/usr/local/bin/perl
#
#   $Id: 50chopblanks.t 229 2002-04-05 03:12:51Z edpratomo $
#
#   This driver should check whether 'ChopBlanks' works.
#

# 2011-01-29 stefansbv
# New version based on t/testlib.pl and Firebird.dbtest

use strict;

BEGIN {
    $|  = 1;
    $^W = 1;
}

use DBI;
use Test::More tests => 38;
#use Test::NoWarnings;

# Make -w happy
$::test_dsn = '';
$::test_user = '';
$::test_password = '';

for my $file ('t/testlib.pl', 'testlib.pl') {
    next unless -f $file;
    eval { require $file };
    BAIL_OUT("Cannot load testlib.pl\n") if $@;
    last;
}

#   Connect to the database
my $dbh =
  DBI->connect( $::test_dsn, $::test_user, $::test_password,
    { ChopBlanks => 1 } );

# DBI->trace(4, "trace.txt");

# ------- TESTS ------------------------------------------------------------- #

ok($dbh, 'dbh OK');

#
#   Find a possible new table name
#
my $table = find_new_table($dbh);
ok($table, "TABLE is '$table'");

#
#   Create a new table
#

my $fld_len = 20;               # length of the name field

my $def =<<"DEF";
CREATE TABLE $table (
    id     INTEGER PRIMARY KEY,
    name   CHAR($fld_len)
)
DEF
ok( $dbh->do($def), qq{CREATE TABLE '$table'} );

my @rows = ( [ 1, '' ], [ 2, ' ' ], [ 3, ' a b c ' ] );

foreach my $ref (@rows) {
    my ($id, $name) = @{$ref};

    #- Insert

    my $insert = qq{ INSERT INTO $table (id, name) VALUES (?, ?) };

    ok(my $sth1 = $dbh->prepare($insert), 'PREPARE INSERT');

    ok($sth1->execute($id, $name), "EXECUTE INSERT ($id)");

    #- Select

    my $sele = qq{SELECT id, name FROM $table WHERE id = ?};

    ok(my $sth2 = $dbh->prepare($sele), 'PREPARE SELECT');

    #-- First try to retrieve without chopping blanks.

    $sth2->{ChopBlanks} = 0;

    ok($sth2->execute($id), "EXECUTE SELECT 1 ($id)");

    ok(my $nochop = $sth2->fetchrow_arrayref, 'FETCHrow ARRAYref 1');

    # Right padding name to the length of the field
    my $n_ncb = sprintf("%-*s", $fld_len, $name);

    is($n_ncb, $nochop->[1], 'COMPARE 1');

    ok($sth2->finish, 'FINISH 1');

    #-- Now try to retrieve with chopping blanks.

    $sth2->{ChopBlanks} = 1;

    ok($sth2->execute($id), "EXECUTE SELECT 2 ($id)");

    ( my $n_cb = $name ) =~ s{\s+$}{}g;

    ok(my $chopping = $sth2->fetchrow_arrayref, 'FETCHrow ARRAYref 2');

    is($n_cb, $chopping->[1], 'COMPARE 2');

    ok($sth2->finish, 'FINISH 2');
}

#
#  Drop the test table
#
$dbh->{AutoCommit} = 1;

ok( $dbh->do("DROP TABLE $table"), "DROP TABLE '$table'" );

#
#   Finally disconnect.
#
ok($dbh->disconnect, 'DISCONNECT');

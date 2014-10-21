#!/usr/bin/perl
#
# 2011-04-13 stefan(s.bv.) Modified to run on Windows.
#
# 2011-01-31 stefan(s.bv.) Created new test:
# Playing with very big | small numbers
# Smallest and biggest integer supported by Firebird:
#   -9223372036854775808, 9223372036854775807
#

use strict;
use warnings;

use Math::BigFloat try => 'GMP';
use Test::More;
use DBI;

use lib 't','.';

use TestFirebird;
my $T = TestFirebird->new;

my ($dbh, $error_str) = $T->connect_to_database();

if ($error_str) {
    BAIL_OUT("Unknown: $error_str!");
}

unless ( $dbh->isa('DBI::db') ) {
    plan skip_all => 'Connection to database failed, cannot continue testing';
}
else {
    plan tests => 9;
}

ok($dbh, 'dbh OK');

# ------- TESTS ------------------------------------------------------------- #

# Find a new table name
my $table = find_new_table($dbh);
ok($table, "TABLE is '$table'");

$dbh->do(<<DEF);
CREATE TABLE $table (
    BINT_MIN  BIGINT,
    BINT_MAX  BIGINT
)
DEF
$dbh->do(<<INS);
INSERT INTO $table (
    BINT_MIN,
    BINT_MAX
) VALUES (
-9223372036854775808,
 9223372036854775807
)
INS

# DBI->trace(4, "trace.txt");

# Expected fetched values
my @correct = (
    [ '-9223372036854775808', '9223372036854775807' ],
);

# Select the values
ok( my $cursor = $dbh->prepare( qq{SELECT * FROM $table} ), 'PREPARE SELECT' );

ok($cursor->execute, 'EXECUTE SELECT');

ok((my $res = $cursor->fetchall_arrayref), 'FETCHALL');

my ($types, $names, $fields) = @{$cursor}{qw(TYPE NAME NUM_OF_FIELDS)};

#my $scale = 0;                               # scale parameter
for (my $i = 0; $i < @$res; $i++) {
    for (my $j = 0; $j < $fields; $j++) {
        my $result  = qq{$res->[$i][$j]};
        my $mresult = Math::BigInt->new($result);

        my $corect  = $correct[$i][$j];
        my $mcorect = Math::BigInt->new($corect);

        #ok($mresult->bacmp($mcorect) == 0, , "Field: $names->[$j]");
        is($mresult, $mcorect, "Field: $names->[$j]");
        # diag "got: $mresult";
        # diag "exp: $mcorect";
    }
}

# Drop the test table
$dbh->{AutoCommit} = 1;

ok( $dbh->do("DROP TABLE $table"), "DROP TABLE '$table'" );

# Finally disconnect.
ok($dbh->disconnect(), 'DISCONNECT');

#-- end TESTS

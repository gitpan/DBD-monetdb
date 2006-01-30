#!perl -I./t

# The contents of this file are subject to the MonetDB Public License
# Version 1.1 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://monetdb.cwi.nl/Legal/MonetDBLicense-1.1.html
#
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
# License for the specific language governing rights and limitations
# under the License.
#
# The Original Code is the MonetDB Database System.
#
# The Initial Developer of the Original Code is CWI.
# Portions created by CWI are Copyright (C) 1997-2006 CWI.
# All Rights Reserved.

$| = 1;

use strict;
use warnings;
use DBI();
use DBD_TEST();
use Time::HiRes qw(gettimeofday tv_interval);

use Test::More;

if (defined $ENV{DBI_DSN}) {
  plan tests => 18;
} else {
  plan skip_all => 'Cannot test without DB info';
}

pass('Insert tests');

my $tbl1 = $DBD_TEST::table_name;
my $tbl2 = $tbl1 . '_2';

my $MAX_ROWS = 200;

my $dbh = DBI->connect or die "Connect failed: $DBI::errstr\n";
pass('Database connection created');

ok( DBD_TEST::tab_create( $dbh, $tbl1 ),"Create table $tbl1");
ok( DBD_TEST::tab_create( $dbh, $tbl2 ),"Create table $tbl2");

# for my $ac ( 0, 1 ) {
#   pass("Testing with AutoCommit $ac");
#   $dbh->{AutoCommit} = $ac;
#
#   # Time how long it takes to run the insert test.
#   my $t_beg = [gettimeofday];
#   run_insert_test( $dbh );
#
#   my $elapsed = tv_interval( $t_beg, [gettimeofday] );
#
#   pass("Run insert test: MAX_ROWS elapsed: $elapsed");
#
#   ok( $dbh->do( "DROP TABLE $tbl1"),"Drop table $tbl1");
# }

# Time how long it takes to run the insert test.
$dbh->{AutoCommit} = 0;
my $t_beg = [gettimeofday];
run_insert_test( $dbh, $tbl1 );

my $elapsed = tv_interval( $t_beg, [gettimeofday] );
pass("Run insert test: MAX_ROWS elapsed: $elapsed");

# Test the number of rows returned by an execute.
my $sql = <<"SQL";
INSERT
  INTO $tbl2( A, B )
SELECT        A, B
  FROM $tbl1
SQL

my $sth = $dbh->prepare( $sql );
ok( defined $sth,'Prepared insert select statement');
my $rc = $sth->execute;
ok( !ref $rc,"Not a ref?");
is( $rc, $MAX_ROWS,"Execute returned $MAX_ROWS rows");
is( $sth->rows, $rc,"Execute sth->rows returned $rc");

$sth->finish; $sth = undef;

# Test the number of rows returned by a do.
$rc = $dbh->do( $sql );
is( $rc, $MAX_ROWS,"Do returned $MAX_ROWS rows");

$dbh->rollback;

$dbh->{AutoCommit} = 1;

ok( $dbh->do("DROP TABLE $tbl1"),"Drop table $tbl1");
ok( $dbh->do("DROP TABLE $tbl2"),"Drop table $tbl2");

ok( $dbh->disconnect,'Disconnect');


sub run_insert_test {
  my $dbh = shift;
  my $tbl = shift;

  my $sth = $dbh->prepare("INSERT INTO $tbl( B ) VALUES( ? )");
  ok( defined $sth,'Insert statement prepared');
  ok( !$dbh->err,'No error on prepare.');

  pass("Loading rows into table: $tbl");

  my $cnt = 0; my $added = 0;
  my $ac = $dbh->{AutoCommit};
  while( $cnt < $MAX_ROWS ) {
    $added += ( $sth->execute("Just a text message for $cnt") || 0 );
  } continue {
    $cnt++;
    $dbh->commit if $ac == 0 && $cnt % 1000 == 0;
    print "# Checkpoint: $cnt\n" if $cnt % 1000 == 0;
  }
  $dbh->commit if $ac == 0;

  ok( $added > 0,"Added $added rows to test using count of $cnt");
  ok( $added == $MAX_ROWS,"Added MAX $MAX_ROWS rows to test using count of $cnt");

  $sth->finish; $sth = undef;
  return;
}
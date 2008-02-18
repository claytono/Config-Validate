use strict;
use warnings;

Test::Class->runtests;

package Test::Boolean;

use base qw(Test::Class);
use Test::More;
use Data::Dumper;
use List::MoreUtils qw(pairwise);
use vars qw($a $b);

use Config::Validate qw(validate);

sub test_all_success :Test(56) {
  my @valid = qw(0 1 t f true false on off y n yes no);
  my @value = qw(0 1 1 0 1    0     1  0   1 0 1   0);
  push(@valid, "yes ", " yes");
  push(@value, 1, 1);
  push(@valid, map { uc($_) } @valid);
  @value = (@value, @value);

  pairwise { test_success($a, $b) } @valid, @value;

  return;
}

sub test_all_failure :Test(7) {
  my @invalid = qw(2 -1 tr fa onn yno);
  push(@invalid, undef);
  test_failure($_) foreach @invalid;

  return;
}

sub test_success {
  my ($valid, $value) = @_;

  my $schema = { booleantest => { type => 'boolean' } };
  my $data = { booleantest => $valid };
  my $result;
  eval { $result = validate($data, $schema) };
  is($@, '', "'$valid' validated correctly");
  is($result->{booleantest}, $value, "$valid == $value");
  return;
}

sub test_failure {
  my $value = shift;

  my $schema = { booleantest => { type => 'boolean' } };
  my $data = { booleantest => $value };
  eval { validate($data, $schema) };
  if (not defined $value) {
    $value = "<undef>";
  }
  like($@, qr/\[\/booleantest/, "'$value' didn't validate (expected)");

  return;
}

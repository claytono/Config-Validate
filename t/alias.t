#!/sw/bin/perl

use strict;
use warnings;

Test::Class->runtests;

package Test::Alias;

use base qw(Test::Class);
use Test::More;
use Data::Dumper;

use Config::Validate;


sub simple_string_alias :Test(1) {
  my $cv = Config::Validate->new;
  $cv->schema({ aliastest => { type => 'boolean',
                               alias => 'alias2',
                             }});
  eval { $cv->validate({alias2 => 0}) };
  is($@, '', 'string alias successful');

  return;
}

sub array_ref_alias :Test(2) {
  my $cv = Config::Validate->new;
  $cv->schema({ aliastest => { type => 'boolean',
                               alias => [ qw(alias2 alias3) ],
                             }});
  eval { $cv->validate({alias2 => 0}) };
  is($@, '', 'arrayref 1 alias successful');
  eval { $cv->validate({alias3 => 0}) };
  is($@, '', 'arrayref 2 alias successful');

  return;
}

sub invalid_alias :Test(1) { 
  my $cv = Config::Validate->new;
  $cv->schema({ aliastest => { type => 'boolean',
                               alias => {},
                             }});
  eval { $cv->validate({alias2 => 0}) };
  like($@, qr/is type HASH, /, 'invalid alias failed (expected)');

  return;
}




#!/sw/bin/perl

use strict;
use warnings;
use Test::More tests => 6;
use Config::General;
use Data::Dumper;
use Storable qw(dclone);

BEGIN { use_ok('Config::Validate') };

my $cv = Config::Validate->new;

my $schema = {arraytest => { type => 'array',
                             subtype => 'string',
                           }
             };
$cv->schema($schema);

{ # Test child with default
  my $result;
  my $testarray = [ qw(abc 123 foo bar) ];
  my $data = { arraytest => $testarray,
             };
  eval { $result = $cv->validate($data) };
  is($@, '', 'array test w/default');

  for (my $i = 0; $i < @$testarray; $i++) {
    is($result->{arraytest}[$i], $testarray->[$i], 
       "array content test ($i == $testarray->[$i])");
  }
}


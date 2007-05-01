#!/sw/bin/perl

use strict;
use warnings;
use Test::More tests => 5;
use Config::General;
use Data::Dumper;

BEGIN { use_ok('Config::Validate') };

my $cv = Config::Validate->new;

{ # normal test case
  $cv->schema({ testinteger => { type => 'integer' }});
  my $value = { testinteger => 1 };
  eval { $cv->validate($value) };
  is ($@, '', 'normal case succeeded');
}

{ # success w/size limits
  $cv->schema({ testinteger => { type => 'integer',
                                min => 1,
                                max => 50,
                              }});
  my $value = { testinteger => 25 };
  eval { $cv->validate($value) };
  is ($@, '', 'size limits succeeded');
}

{ # failure for max size
  $cv->schema({testinteger => { type => 'integer',
                               min => 1,
                               max => 1,
                             }});
  my $value = { testinteger => 50 };
  eval { $cv->validate($value) };
  like($@, qr/50 is larger than the maximum allowed \(1\)/, 
       "max failed (expected)");
}

{ # failure for min len
  $cv->schema({ testinteger => { type => 'integer',
                                min => 1000,
                                max => 1000,
                              }});
  my $value = { testinteger => 25 };
  eval { $cv->validate($value) };
  like($@, qr/25 is smaller than the minimum allowed \(1000\)/, 
       "min failed (expected)");
}


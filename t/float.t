#!/sw/bin/perl

use strict;
use warnings;
use Test::More tests => 6;
use Config::General;
use Data::Dumper;

BEGIN { use_ok('Config::Validate') };

my $cv = Config::Validate->new;

{ # normal test case
  $cv->schema({ testfloat => { type => 'float' }});
  my $value = { testfloat => 1.1 };
  eval { $cv->validate($value) };
  is ($@, '', 'normal case succeeded');
}

{ # negative test case
  $cv->schema({ testfloat => { type => 'float' }});
  my $value = { testfloat => -1.1 };
  eval { $cv->validate($value) };
  is ($@, '', 'negative case succeeded');
}

{ # success w/size limits
  $cv->schema({ testfloat => { type => 'float',
                                min => 1.1,
                                max => 50.1,
                              }});
  my $value = { testfloat => 25.5 };
  eval { $cv->validate($value) };
  is ($@, '', 'size limits succeeded');
}

{ # failure for max size
  $cv->schema({testfloat => { type => 'float',
                               min => 1.1,
                               max => 1.1,
                             }});
  my $value = { testfloat => 50.1 };
  eval { $cv->validate($value) };
  like($@, qr/50.1\d* is larger than the maximum allowed \(1.1\d*\)/, 
       "max failed (expected)");
}

{ # failure for min len
  $cv->schema({ testfloat => { type => 'float',
                                min => 1000.1,
                                max => 1000.1,
                              }});
  my $value = { testfloat => 25.5 };
  eval { $cv->validate($value) };
  like($@, qr/25.5\d* is smaller than the minimum allowed \(1000.1\d*\)/, 
       "min failed (expected)");
}


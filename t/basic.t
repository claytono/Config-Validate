#!/sw/bin/perl

use strict;
use warnings;
use Test::More tests => 6;
use Config::General;
use Data::Dumper;
use Storable qw(dclone);

BEGIN { use_ok('Config::Validate') };

my $cv = Config::Validate->new;

{ # No type specified

  $cv->schema({test => {}});
  eval { $cv->validate({blah => 1}) };
  like($@, qr/No type specified for \[\/test\]/, 
       'no type specified: failed (expected)');
}

{ # Invalid type specified

  $cv->schema({test => { type => 'blah' }});
  eval { $cv->validate({blah => 1}) };
  like($@, qr/Invalid type 'blah' specified for \[\/test\]/, 
       'no type specified: failed (expected)');
}

{ # Invalid key specified in data/config

  $cv->schema({test => { type => 'boolean' }});
  eval { $cv->validate({test => 1, blah2 => 1, blah3 => 1}) };
  like($@, qr/unknown items were found: blah2, blah3/, 
       'invalid key found (expected)');
}

{ # Required key not found

  $cv->schema({test => { type => 'boolean' }});
  eval { $cv->validate({blah2 => 1, blah3 => 1}) };
  like($@, qr/Required item \[\/test\] was not found/, 
       'invalid key found (expected)');
}

{ # Optional parameter set false

  $cv->schema({test => { type => 'boolean',
                         optional => 0,
                       },
              }
             );
  eval { $cv->validate({blah2 => 1, blah3 => 1}) };
  like($@, qr/Required item \[\/test\] was not found/, 
       'invalid key found (expected)');
}

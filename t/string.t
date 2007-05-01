#!/sw/bin/perl

use strict;
use warnings;
use Test::More tests => 9;
use Config::General;
use Data::Dumper;

BEGIN { use_ok('Config::Validate', ':all') };

{ # normal test case
  my $def = { teststring => { type => 'string' }};
  my $value = { teststring => 'test' };
  eval { validate($value, $def) };
  is ($@, '', 'normal case succeeded');
}

{ # success w/length limits
  my $def = { teststring => { type => 'string',
                              minlen => 1,
                              maxlen => 50,
                            }};
  my $value = { teststring => 'test' };
  eval { validate($value, $def) };
  is ($@, '', 'length limits succeeded');
}

{ # failure for max len
  my $def = { teststring => { type => 'string',
                              minlen => 1,
                              maxlen => 1,
                            }};
  my $value = { teststring => 'test' };
  eval { validate($value, $def) };
  like($@, qr/length of string is 4, but must be less than 1/, 
       "maxlen failed (expected)");
}

{ # failure for min len
  my $def = { teststring => { type => 'string',
                              minlen => 1000,
                              maxlen => 1000,
                            }};
  my $value = { teststring => 'test' };
  eval { validate($value, $def) };
  like($@, qr/length of string is 4, but must be greater than 1000/, 
       "maxlen failed (expected)");
}

{ # success w/regex - qr//
  my $def = { teststring => { type => 'string',
                              regex => qr/^t/i,
                            }};
  my $value = { teststring => 'test' };
  eval { validate($value, $def) };
  is($@, '', 'regex match succeeded - qr//');
}

{ # success w/regex - string
  my $def = { teststring => { type => 'string',
                              regex => '^t',
                            }};
  my $value = { teststring => 'test' };
  eval { validate($value, $def) };
  is($@, '', 'regex match succeeded - string');
}

{ # failure w/regex - qr//
  my $def = { teststring => { type => 'string',
                              regex => qr/^y/i,
                            }};
  my $value = { teststring => 'test' };
  eval { validate($value, $def) };
  like($@, qr/regex (\S+?) didn't match 'test'/, 'regex match failed (expected) - qr//');
}

{ # failure w/regex - string
  my $def = { teststring => { type => 'string',
                              regex => '^y',
                            }};
  my $value = { teststring => 'test' };
  eval { validate($value, $def) };
  like($@, qr/regex (\S+?) didn't match 'test'/, 'regex match failed (expected) - string');
}




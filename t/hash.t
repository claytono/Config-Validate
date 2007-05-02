#!/sw/bin/perl

use strict;
use warnings;
use Test::More tests => 9;
use Config::General;
use Data::Dumper;
use Storable qw(dclone);

BEGIN { use_ok('Config::Validate') };

my $cv = Config::Validate->new;

my $schema = {hashtest => { type => 'hash',
                            keytype => 'string',
                            child => { 
                              test => { type => 'string',
                                        default => 'blah'
                                       },
                              test2 => { type => 'boolean'},
                            },
                          }
             };
$cv->schema($schema);

{ # Test child with default
  my $result;
  my $data = { hashtest => 
               { test1 => { test2 => 1 },
                 test2 => { test => 'foo',
                            test2 => 0 },
               },
             };
  eval { $result = $cv->validate($data) };
  is($@, '', 'hash test w/default');
  is($result->{hashtest}{test1}{test}, 'blah', "default successful");
  is($result->{hashtest}{test2}{test}, 'foo', "explicitly setting default successful");
}

{ # Test w/o child validation
  my $newschema = dclone($schema);
  delete $newschema->{hashtest}{child};
  $cv->schema($newschema);

  my $data = { hashtest => 
               { test1 => 1,
                 test2 => 2,
               },
             };

  my $result;
  eval { $result = $cv->validate($data) };
  is($@, '', 'hash test w/default');
  is($result->{hashtest}{test1}, 1, 'key1 validated');
  is($result->{hashtest}{test2}, 2, 'key2 validated');
}

{ # Test child w/no keytype
  my $newschema = dclone($schema);
  delete $newschema->{hashtest}{keytype};
  $cv->schema($newschema);

  my $data = { hashtest => 
               { test1 => { test2 => 1 },
                 test2 => { test => 'foo',
                            test2 => 0 },
               },
             };

  my $result;
  eval { $result = $cv->validate($data) };
  like($@, qr/No keytype specified/, 'No keytype specified');
}

{ # Test child w/bad keytype
  my $newschema = dclone($schema);
  $newschema->{hashtest}{keytype} = 'badkeytype';
  $cv->schema($newschema);

  my $data = { hashtest => 
               { test1 => { test2 => 1 },
                 test2 => { test => 'foo',
                            test2 => 0 },
               },
             };

  my $result;
  eval { $result = $cv->validate($data) };
  like($@, qr/Invalid keytype 'badkeytype' specified/, 'Bad keytype specified');
}

#!/sw/bin/perl

use strict;
use warnings;
use Test::More tests => 5;
use Config::General;
use Data::Dumper;
use Scalar::Util::Clone qw(clone);

BEGIN { use_ok('Config::Validate') };

my $test = 0;

Config::Validate->add_default_type(name => 'test1',
                                   init => sub { 
                                     is($test, 0, 'default type - init ran');
                                     $test++;
                                   },
                                   validate => sub {
                                     is($test, 1, 'default type - validate ran');
                                     $test++;
                                   },
                                   finish => sub {
                                     is($test, 2, 'default type - finish ran');
                                     $test++;
                                   },
                                  );

my $cv = Config::Validate->new(schema => {test => {type => 'test1'}});
eval { $cv->validate({test => 1}); };
is($@, '', "validate completed without error");

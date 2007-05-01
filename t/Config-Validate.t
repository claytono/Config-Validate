#!/sw/bin/perl

use strict;
use warnings;
use Test::More tests => 2;
use Config::General;
use Data::Dumper;
use Carp::Always;

BEGIN { use_ok('Config::Validate', 'validate') };

my $plugin_schema = {
  blackhole => { type => 'nested',
                 optional => 1,
                 child => { 
                   domains => { 
                     type => 'string',
                     alias => 'domain',
                   },
                 },
               },
  
  nxdomain => { type => 'nested',
                optional => 1,
                child => { 
                  domains => { 
                    type => 'string',
                    alias => 'domain',
                  },
                },
              },
  enum => { type => 'nested',
            optional => 1,
            child => {
              ttl => { type => 'integer',
                       default => 600, },
              timeout => { type => 'integer',
                           default => 1000, },
              domains => { 
                type => 'hash',
                keytype => 'string',
                alias => 'domain',
                child => {
                  dialplan => { type => 'string' },
                  areaofauthority => { type => 'string' },
                  logmissing => { type => 'boolean',
                                  default => 0 
                                 },
                }
               },
            },
          },
};

my $schema = {
  cleantime => { type     => 'integer',
                 default  => 30,
               },
  statstime => { type     => 'integer',
                 default  => 30,
               },
  ldapconfig => { type     => 'string',
                  optional => 1,
                },
  plugins => { type => 'nested',
               alias => 'plugin',
               optional => 1,
               child => $plugin_schema,
             },
 }; 

my $config = Config::General->new(-ConfigFile => 't/test-config.conf',
                                  -LowerCaseNames => 1,
                                 );
isa_ok($config, 'Config::General');

my %config = $config->getall;
#print STDERR Dumper(\%config);

my $new = Config::Validate::validate(\%config, $schema);
#print STDERR Dumper($new);

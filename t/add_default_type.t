#!/sw/bin/perl

use strict;
use warnings;

Test::Class->runtests;

package Test::AddDefaultType;

use base qw(Test::Class);
use Test::More;

BEGIN { use_ok('Config::Validate') };

sub teardown :Test(teardown) {
  Config::Validate::reset_default_types();
}

sub no_args :Test {
  eval { Config::Validate::add_default_type(); };
  like($@, qr/Mandatory parameter 'name' missing in call/i, 
       "No argument test");
  return;
}

sub name_only :Test {
  eval { Config::Validate->add_default_type(name => 'name_only'); };
  like($@, qr/No callbacks defined for type 'name_only'/i, 
       "Name only test");
  return;
}

sub init_hook :Test(2) {
  my $init_ran = 0;
  Config::Validate->add_default_type(name => 'init_hook',
                                     init => sub { $init_ran++ },
                                    ); 

  my $cv = Config::Validate->new(schema => {test => {type => 'integer'}});
  eval { $cv->validate({test => 1}); };
  is($@, '', "validate completed without error");
  ok($init_ran, "init ran");

  return;
}

sub finish_hook :Test(2) {
  my $finish_ran = 0;
  Config::Validate->add_default_type(name => 'finish_hook',
                                     finish => sub { $finish_ran++ },
                                    ); 

  my $cv = Config::Validate->new(schema => {test => {type => 'integer'}});
  eval { $cv->validate({test => 1}); };
  is($@, '', "validate completed without error");
  ok($finish_ran, "finish ran");

  return;
}

sub class_method_validate :Test(2) {
  my $counter = 0;
  Config::Validate->add_default_type(name => 'class_method_validate',
                                     validate => sub { $counter++ },
                                    ); 

  my $cv = Config::Validate->new(schema => 
                                 { test => {
                                   type => 'class_method_validate'}
                                 }
                                );

  eval { $cv->validate({test => 1}); };
  is($@, '', "validate completed without error");
  is($counter, 1, "callback ran");

  return;
}

sub function_validate :Test(2) {
  my $counter = 0;
  Config::Validate::add_default_type(name => 'function_validate',
                                     validate => sub { $counter++ },
                                    );

  my $cv = Config::Validate->new(schema => 
                                 { test => { 
                                   type => 'function_validate' },
                                 }
                                );

  eval { $cv->validate({test => 1}); };
  is($@, '', "validate completed without error");
  is($counter, 1, "callback ran");

  return;
}

sub instance_validate :Test(4) {
  my $cv = Config::Validate->new();

  my $counter = 0;
  $cv->add_default_type(name => 'instance_validate',
                        validate => sub { $counter++ },
                       );

  $cv->schema({ test => { type => 'instance_validate' }});

  eval { $cv->validate({test => 1}); };
  is($@, '', "validate completed without error");
  is($counter, 1, "callback ran");

  # Check to make sure it was added to the default table also, by
  # creating a new instance.
  $cv = Config::Validate->new(schema => 
                              { test => { 
                                type => 'instance_validate' },
                              }
                             );

  eval { $cv->validate({test => 1}); };
  is($@, '', "validate completed without error second time");
  is($counter, 2, "callback ran second time");

  return;
}

sub duplicate_type :Test(1) {
  my $counter = 0;
  Config::Validate::add_default_type(name => 'duplicate_type',
                                     validate => sub { },
                                    );
  
  eval {
    Config::Validate::add_default_type(name => 'duplicate_type',
                                       validate => sub { },
                                      );
  };
  like($@, qr/Attempted to add type 'duplicate_type' that already/, 
       "adding duplicate type failed as expected");

  return;
}

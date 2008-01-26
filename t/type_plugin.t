#!/sw/bin/perl

use strict;
use warnings;

Test::Class->runtests;

package Test::TypePlugin;

use base qw(Test::Class);
use Test::More;

BEGIN { use_ok('Config::Validate') };

sub teardown :Test(teardown) {
  Config::Validate::reset_default_types();
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

sub class_method_validate :Test(3) {
  my $counter = 0;
  Config::Validate->add_default_type(name => 'class_method_validate',
                                     validate => sub {
                                       is($counter, 0, 'class: validate ran');
                                       $counter++;
                                     },
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

sub function_validate :Test(3) {
  my $counter = 0;
  Config::Validate::add_default_type(name => 'function_validate',
                                     validate => sub {
                                       is($counter, 0, 'function: validate ran');
                                       $counter++;
                                     },
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

sub instance_validate :Test(3) {
  my $counter = 0;
  Config::Validate::add_default_type(name => 'instance_validate',
                                     validate => sub {
                                       is($counter, 0, 'instance: validate ran');
                                       $counter++;
                                     },
                                    );

  my $cv = Config::Validate->new(schema => 
                                 { test => { 
                                   type => 'instance_validate' },
                                 }
                                );

  eval { $cv->validate({test => 1}); };
  is($@, '', "validate completed without error");
  is($counter, 1, "callback ran");

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

#!/sw/bin/perl

use strict;
use warnings;

Test::Class->runtests;

package Test::AddDefaultType;

use base qw(Test::Class);
use Test::More;

use Config::Validate qw(validate);

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

sub validate_fail_on_type_with_init_hook :Test(2) {
  my $init_ran = 0;
  Config::Validate->add_default_type(name => 'init_hook',
                                     init => sub { $init_ran++ },
                                    ); 

  my $cv = Config::Validate->new(schema => {test => {type => 'init_hook'}});
  eval { $cv->validate({test => 1}); };
  like($@, qr/No validate callback defined for type 'init_hook'/, 
       "validate failed as expected");
  ok($init_ran, "init ran");

  return;
}

sub init_hook :Test(5) {
  my $init_ran = 0;

  my $schema = { test => { type => 'integer' } };
  my $cfg = { test => 1 };
  my $cb = sub { 
    my ($self_arg, $schema_arg, $cfg_arg) = @_;
    isa_ok($self_arg, 'Config::Validate', 
           "param 1 isa Config::Validate");
    is_deeply($schema, $schema_arg, "param 2 matches"); 
    is_deeply($cfg, $cfg_arg, "param 3 matches"); 
    $init_ran++;
    return;
  };

  Config::Validate->add_default_type(name => 'init_hook',
                                     init => $cb,
                                    ); 

  my $cv = Config::Validate->new(schema => $schema);
  eval { $cv->validate($cfg); };
  is($@, '', "validate completed without error");
  is($init_ran, 1, "init ran once");

  return;
}

sub finish_hook :Test(5) {
  my $finish_ran = 0;

  my $schema = { test => { type => 'integer' } };
  my $cfg = { test => 1 };
  my $cb = sub { 
    my ($self_arg, $schema_arg, $cfg_arg) = @_;
    isa_ok($self_arg, 'Config::Validate', 
           "param 1 isa Config::Validate");
    is_deeply($schema, $schema_arg, "param 2 matches"); 
    is_deeply($cfg, $cfg_arg, "param 3 matches"); 
    $finish_ran++;
    return;
  };

  Config::Validate->add_default_type(name => 'finish_hook',
                                     finish => $cb,
                                    ); 

  my $cv = Config::Validate->new(schema => $schema);
  eval { $cv->validate($cfg); };
  is($@, '', "validate completed without error");
  is($finish_ran, 1, "finish ran once");
  
  return;
}

sub class_method_per_item :Test(5) {

  my $counter = 0;

  my $init = sub { 
    $counter++;
    is($counter, 1, "init_cb fired in order");
  };
  
  my $validate = sub { 
    $counter++;
    is($counter, 2, "validate_cb fired in order");
  };
  
  my $finish = sub { 
    $counter++;
    is($counter, 3, "finish_cb fired in order");
  };
  
  Config::Validate->add_default_type(name => 'class_method',
                                     item_init   => $init,
                                     validate    => $validate,
                                     item_finish => $finish,
                                    ); 

  my $cv = Config::Validate->new(schema => 
                                 { test => {
                                   type => 'class_method'}
                                 }
                                );

  eval { $cv->validate({test => 1}); };
  is($@, '', "validate completed without error");
  is($counter, 3, "callback ran");

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

sub update_type :Test(3) {
  my ($sub1, $sub2) = (0, 0);
  Config::Validate::add_default_type(name => 'duplicate_type',
                                     validate => sub { $sub1 = 1 },
                                    );
  
  eval {
    Config::Validate::add_default_type(name => 'duplicate_type',
                                       validate => sub { $sub2 = 1 },
                                      );
  };
  is($@, '', "updating type didn't fail");

  validate(schema => { test => { type => 'duplicate_type' }},
           config => { test => 1 });

  is($sub1, 0, "sub1 didn't run");
  is($sub2, 1, "sub2 did run");
  return;
}

sub supplement_type :Test(12) {
  my $counter = 0;
  my $validate = sub {
    my ($self, $ref, $def, $path) = @_;
    $counter++;
    is($counter, 2, "validate called second");

    isa_ok($self, 'Config::Validate');
    isa_ok($ref, "SCALAR", "config item passed by reference");
    is($$ref, 1, "config item has correct value");
    is_deeply($def, { type => 'supplement_type' },
              "definition is correct");
    is_deeply($path, [ 'test' ], "path is correct");
  };
  my $item_init = sub {
    my ($self, $ref, $def, $path) = @_;
    $counter++;
    is($counter, 1, "item_init called first");

    isa_ok($self, 'Config::Validate');
    isa_ok($ref, "SCALAR", "config item passed by reference");
    is($$ref, 1, "config item has correct value");
    is_deeply($def, { type => 'supplement_type' },
              "definition is correct");
    is_deeply($path, [ 'test' ], "path is correct");
  };

  Config::Validate::add_default_type(name => 'supplement_type',
                                     validate => $validate,
                                    );
  
  Config::Validate::add_default_type(name => 'supplement_type',
                                     item_init => $item_init,
                                    );

  validate(schema => { test => { type => 'supplement_type' }},
           config => { test => 1 });

  return;
}


#!/sw/bin/perl

use strict;
use warnings;

Test::Class->runtests;

package Test::AddType;

use base qw(Test::Class);
use Test::More;

use Config::Validate;

sub setup :Test(setup => 1) {
  my ($self) = @_;
  $self->{schema} = { test => { type => 'test_type' } };
  $self->{cv} = Config::Validate->new();
  isa_ok($self->{cv}, 'Config::Validate');
  
  $self->{counter} = 0;
  $self->{callback} = sub { $self->{counter}++ };
  
  return;
}

sub no_args :Test {
  my ($self) = @_;

  eval { $self->{cv}->add_type(); };
  like($@, qr/Mandatory parameter 'name' missing in call/i, 
       "No argument test");
  return;
}

sub name_only :Test {
  my ($self) = @_;

  eval { $self->{cv}->add_type(name => 'name_only'); };
  like($@, qr/No callbacks defined for type 'name_only'/i, 
       "Name only test");
  return;
}

sub init_hook :Test(2) {
  my ($self) = @_;

  $self->{cv}->add_type(name => 'test_type',
                        init => $self->{callback},
                       );
  $self->{schema}{test}{type} = 'integer';
  $self->{cv}->schema($self->{schema});
  
  eval { $self->{cv}->validate({test => 1}); };
  is($@, '', "validate completed without error");
  is($self->{counter}, 1, "init ran");

  return;
}

sub finish_hook :Test(2) {
  my ($self) = @_;

  $self->{cv}->add_type(name => 'test_type',
                        finish => $self->{callback},
                       ); 
  $self->{schema}{test}{type} = 'integer';
  $self->{cv}->schema($self->{schema});

  eval { $self->{cv}->validate({test => 1}); };
  is($@, '', "validate completed without error");
  is($self->{counter}, 1, "finish ran");

  return;
}

sub validate :Test(2) {
  my ($self) = @_;

  $self->{cv}->add_type(name => 'test_type',
                        validate => $self->{callback},
                       ); 
  $self->{cv}->schema($self->{schema});

  eval { $self->{cv}->validate({test => 1}); };
  is($@, '', "validate completed without error");
  is($self->{counter}, 1, "callback ran");

  return;
}

sub duplicate_type  {
  my ($self) = @_;

  $self->{cv}->add_type(name => 'test_type',
                        validate => $self->{callback},
                       ); 
  $self->{cv}->schema($self->{schema});

  eval { $self->{cv}->validate({test => 1}); };
  is($@, '', "validate completed without error");
  is($self->{counter}, 1, "callback ran first time");

  eval {
    $self->{cv}->add_type(name => 'test_type',
                          validate => $self->{callback},
                         ); 
  };
  like($@, qr/test/, "validate completed without error");
  is($self->{counter}, 1, "callback ran once");

  return;
}

sub update_type :Test(2) {
  my ($self) = @_;
  my ($sub1, $sub2) = (0, 0);
  
  $self->{cv}->add_type(name => 'duplicate_type',
                        validate => sub { $sub1 = 1 },
                       );
  
  $self->{cv}->add_type(name => 'duplicate_type',
                        validate => sub { $sub2 = 1 },
                       );

  $self->{cv}->schema({ test => { type => 'duplicate_type' }});
  $self->{cv}->validate(config => { test => 1 });

  is($sub1, 0, "sub1 didn't run");
  is($sub2, 1, "sub2 did run");
  return;
}

sub supplement_type :Test(12) {
  my ($self) = @_;

  my $counter = 0;
  my $validate = sub {
    my ($cv, $ref, $def, $path) = @_;
    $counter++;
    is($counter, 2, "validate called second");

    isa_ok($cv, 'Config::Validate');
    isa_ok($ref, "SCALAR", "config item passed by reference");
    is($$ref, 1, "config item has correct value");
    is_deeply($def, { type => 'supplement_type' },
              "definition is correct");
    is_deeply($path, [ 'test' ], "path is correct");
  };
  my $item_init = sub {
    my ($cv, $ref, $def, $path) = @_;
    $counter++;
    is($counter, 1, "item_init called first");

    isa_ok($cv, 'Config::Validate');
    isa_ok($ref, "SCALAR", "config item passed by reference");
    is($$ref, 1, "config item has correct value");
    is_deeply($def, { type => 'supplement_type' },
              "definition is correct");
    is_deeply($path, [ 'test' ], "path is correct");
  };

  $self->{cv}->add_default_type(name => 'supplement_type',
                                validate => $validate,
                               );
  
  $self->{cv}->add_default_type(name => 'supplement_type',
                                item_init => $item_init,
                               );

  $self->{cv}->schema({ test => { type => 'supplement_type' }});
  $self->{cv}->validate(config => { test => 1 });

  return;
}

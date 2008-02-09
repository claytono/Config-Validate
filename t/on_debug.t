#!/sw/bin/perl

use strict;
use warnings;

Test::Class->runtests;

package Test::OnDebug;

use base qw(Test::Class);
use Test::More;
use Data::Dumper;
use Storable qw(dclone);

use Config::Validate qw(validate);

sub on_debug :Test(4) {
  my $cv;
  my $call_count = 0;
  my $on_debug = sub {
    my ($self, @args) = @_;
    is($self, $cv, "\$self matches C::V object");
    is(join('', @args), "Validating [/test]", "message as expected");
    $call_count++;
  };

  $cv = Config::Validate->new(debug => 1,
                              on_debug => $on_debug);
  $cv->schema({test => { type => 'boolean' }});
  eval { $cv->validate({test => 1}) };
  is($@, '', "validate successful");
  is($call_count, 1, "on_debug ran once");
  return;
}


#!/sw/bin/perl

use strict;
use warnings;
use Test::More tests => 5;
use Config::General;
use Data::Dumper;
use File::Temp qw(tempdir tmpnam);

BEGIN { use_ok('Config::Validate') };

my $cv = Config::Validate->new;

{ # normal file test case
  $cv->schema({ testfile => { type => 'file' }});
  my $tempfile = File::Temp->new(UNLINK => 0, 
                                 CLEANUP => 1);

  my $value = { testfile => $tempfile->filename };
  eval { $cv->validate($value) };
  is ($@, '', 'normal file case succeeded (' . $tempfile->filename .  ')');
}

{ # symlink test case
  $cv->schema({ testfile => { type => 'file' }});
  my $tempfile = File::Temp->new(UNLINK => 0, 
                                 CLEANUP => 1);
  my $symlink_filename = tmpnam();
  my $rc = symlink $tempfile->filename, $symlink_filename;
  ok($rc, "symlink operation succeeded");

  my $value = { testfile => $symlink_filename };
  eval { $cv->validate($value) };
  is ($@, '', sprintf('file w/symlink case succeeded (%s -> %s)',
                      $symlink_filename, $tempfile->filename));
  unlink($symlink_filename);
}

{ # directory test case
  $cv->schema({ testdir => { type => 'directory' }});
  
  my $tempdir = tempdir("config-validate-dirtest-XXXXX",
                        CLEANUP => 1,
                        TMPDIR => 1,
                       );

  my $value = { testdir => $tempdir };
  eval { $cv->validate($value) };
  is ($@, '', 'directory case succeeded (' . $tempdir .  ')');
}


use 5.008005;
use ExtUtils::MakeMaker;
use Cwd;

eval {
 require ExtUtils::MakeMaker::Coverage;
};

my $do_coverage = ($@ == '');

WriteMakefile(
    NAME              => 'Config::Validate',
    VERSION_FROM      => 'lib/Config/Validate.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Config/Validate.pm', # retrieve abstract from module
       AUTHOR         => "Clayton O'Neill <coneill\@eng.rr.com>") : ()),
);

sub MY::postamble {
  my $cwd = cwd();
  my %defines = (
    _sourcedir => $cwd,
    _srcrpmdir => $cwd,
    _rpmdir => $cwd,
    _builddir => "$cwd/BUILD",
   );

  my $defines = '';
  while (my ($key, $value) = each %defines) {
    $defines .= "--define '$key $value' ";
  }

  my $fragment = qq{

rpm: \$(DISTVNAME).tar\$(SUFFIX)
\trm -rf $cwd/BUILD
\tmkdir $cwd/BUILD
\trpmbuild -ba $defines \$(DISTNAME)-pm.spec
\trm -rf $cwd/BUILD

srpm: \$(DISTVNAME).tar\$(SUFFIX)
\trpmbuild -bs $defines \$(DISTNAME)-pm.spec

  };
  if ($do_coverage) {
    print "Found ExtUtils::MakeMaker::Coverage, including in Makefile\n";
    return ExtUtils::MakeMaker::Coverage::testcover() . $fragment;
  } else {
    return $fragment;
  }
}

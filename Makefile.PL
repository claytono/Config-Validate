use 5.008005;
use ExtUtils::MakeMaker;
use Cwd;

eval {
 require ExtUtils::MakeMaker::Coverage;
};

my $do_coverage = ($@ eq '');

WriteMakefile(
    NAME              => 'Config::Validate',
    VERSION_FROM      => 'lib/Config/Validate.pm', # finds $VERSION
    PREREQ_PM         => { 'Config::General' => 0,
			   'Object::InsideOut' => 0,
			   'Scalar::Util::Clone' => 0,
			   'Params::Validate' => 0,
			   'Data::Validate::Domain' => 0 # Should be optional
			   
    }, # e.g., Module::Name => 1.1
    dist => {
      COMPRESS => 'bzip2 --best -f',
      SUFFIX => '.bz2'
     },
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
\tmakerpm rpm \$(DISTNAME)-pm.spec \$(VERSION)

srpm: \$(DISTVNAME).tar\$(SUFFIX)
\tmakerpm srpm \$(DISTNAME)-pm.spec \$(VERSION)

  };
  if ($do_coverage) {
    print "Found ExtUtils::MakeMaker::Coverage, including in Makefile\n";
    return ExtUtils::MakeMaker::Coverage::testcover() . $fragment;
  } else {
    print "Could not find ExtUtils::MakeMaker::Coverage, so testcover is disabled.\n";
    return $fragment;
  }
}

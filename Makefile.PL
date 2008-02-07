use 5.008000;
use ExtUtils::MakeMaker;
use Cwd;

eval {
 require ExtUtils::MakeMaker::Coverage;
};

my $do_coverage = ($@ eq '');

WriteMakefile(
    NAME              => 'Config::Validate',
    VERSION_FROM      => 'lib/Config/Validate.pm', # finds $VERSION
    PREREQ_PM         => { 
      'Object::InsideOut'      => 0,
      'Scalar::Util::Clone'    => 0,
      'Params::Validate'       => 0,
      'Data::Validate::Domain' => 0,
      'Test::Class'            => 0,
      'Carp::Clan'             => 0,
    }, 
    ABSTRACT_FROM  => 'lib/Config/Validate.pm', 
    AUTHOR         => "Clayton O'Neill",
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

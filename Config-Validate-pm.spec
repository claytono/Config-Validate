%define perl_binary %{_bindir}/perl 
%define perl_longversion %(%{perl_binary} -e 'print "$]\n"')

%define distname Config-Validate
Name: %{distname}-pm
Version: @@VERSION@@
Release: 1
Group: Development/Perl
License: unknown
Summary: Config and data structure validator
Source: Config-Validate-%{version}.tar.bz2
BuildRoot: %{_tmppath}/%{name}-root
BuildRequires: perl-devel

Requires: perl(:MODULE_COMPAT_5.008005)
%if "%{perl_longversion}" < "5.007003"
BuildRequires: perl(Test::More) >= 0.18
%endif
%if "%{perl_longversion}" < "5.007003"
Requires: perl(Test::More) >= 0.18
%endif

%description
none

%prep
%setup -q -n %{distname}-%{version} 

%build
CFLAGS="$RPM_OPT_FLAGS" 
export CFLAGS
CC=gcc
export CC
AUTOMATED_TESTING=1 
export AUTOMATED_TESTING
PERL_EXTUTILS_AUTOINSTALL="--skipdeps"
export PERL_EXTUTILS_AUTOINSTALL
%{perl_binary} Makefile.PL </dev/null
make

# This is gross, allow people to specify --with test and
# --without test on rpm commandline
%{?_with_test: %{?_without_test: %{error Can't make test and not make test}}}
%{!?_with_test: %{!?_without_test: %define make_test 1}}
%{?_without_test: %define make_test 0}
%if %{make_test}
make test
%endif

%clean 
rm -rf $RPM_BUILD_ROOT

%install
rm -rf $RPM_BUILD_ROOT
eval `perl '-V:installarchlib'`
mkdir -p $RPM_BUILD_ROOT/$installarchlib
make install_vendor DESTDIR=%{buildroot}

:>%{distname}-%{version}-filelist
for i in `find $RPM_BUILD_ROOT/%{_prefix} -type f -print | sed "s@^$RPM_BUILD_ROOT@@g"`; do
  if expr match $i '.*perllocal'; then
    echo "%exclude $i" >> %{distname}-%{version}-filelist
  elif expr match $i '.*\.packlist$'; then
    echo "%exclude $i" >> %{distname}-%{version}-filelist
  else
    echo "$i" >> %{distname}-%{version}-filelist
  fi
done

if [ "$(cat %{distname}-%{version}-filelist)X" = "X" ] ; then
    echo "ERROR: EMPTY FILE LIST"
    exit -1
fi

find %{buildroot} -type f -print0|xargs -0 fixbangpaths %{_bindir}

%files -f %{distname}-%{version}-filelist
%defattr(-,root,root)




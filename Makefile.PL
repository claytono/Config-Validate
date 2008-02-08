use inc::Module::Install;

name 'Config-Validate';
all_from 'lib/Config/Validate.pm';

requires 'Object::InsideOut'      => 0;
requires 'Scalar::Util::Clone'    => 0;
requires 'Params::Validate'       => 0;
requires 'Data::Validate::Domain' => 0;
requires 'Carp::Clan'             => 0;
requires 'List::MoreUtils'        => 0;

build_requires 'Test::Class' => 0;

recommends 'Config::General' => 0;
recommends 'Data::Path'      => 0;


WriteAll;

package Config::Validate;
use strict;
use warnings;

# There is too much DWIMery here for this to be practical
## no critic (RequireArgUnpacking, ProhibitDoubleSigils)

{
  use Object::InsideOut;

  use Data::Dumper;
  use Scalar::Util::Clone qw(clone);
  use Scalar::Util qw(blessed);
  use Params::Validate qw(validate_with :types);
  use Carp::Clan;

  use Exporter qw(import);
  our @EXPORT_OK = qw(validate);
  our %EXPORT_TAGS = ('all' => \@EXPORT_OK);
  
  our $VERSION = '0.0.1';

  my @schema :Field :Accessor(schema) :Arg(schema);
  my @array_allows_scalar :Field 
                          :Accessor(array_allows_scalar) 
                          :Arg(Name => 'array_allows_scalar', Default => 1);
  my @debug  :Field :Accessor(debug) :Arg(debug);
  my @on_debug :Field 
               :Accessor(on_debug) 
               :Arg(on_debug) 
               :Default(\&debug_print);
  my @types  :Field;

  my %default_types = (
    integer   => { validate => \&_validate_integer },
    float     => { validate => \&_validate_float },
    string    => { validate => \&_validate_string },
    boolean   => { validate => \&_validate_boolean },
    hash      => { validate => \&_validate_hash }, 
    array     => { validate => \&_validate_array,
                   byreference => 1,
                 }, 
    directory => { validate => \&_validate_directory },
    file      => { validate => \&_validate_file },
    domain    => { validate => \&_validate_domain },
    hostname  => { validate => \&_validate_hostname },
    nested    => { validate => sub { croak "'nested' is not valid here"; }},
  );

  my %types = %default_types;

  sub _init :Init {
    my ($self, $args) = @_;
    
    $types[$$self] = clone(\%types);
    return;
  }

  sub _parse_add_type_params {
    # XXX: This should be updated to allow 'byreference'
    my $spec = { name => { type => SCALAR },
                 validate => { type => CODEREF,
                               optional => 1,
                             },
                 init     => { type => CODEREF,
                               optional => 1,
                             },
                 finish   => { type => CODEREF,
                               optional => 1,
                             },
               };
    return validate_with(params         => \@_,
                         spec           => $spec,
                         stack_skip     => 2,
                         normalize_keys => sub {
                           return lc $_[0];
                         },
                        );
  }

  sub add_default_type {
    # this is a function, but if it's called as a method, that's
    # fine too.
    my $self;
    if (@_) {
      $self = shift if blessed $_[0];
      shift if $_[0] eq 'Config::Validate';
    }
      
    my %p = _parse_add_type_params(@_);    
    if ($self) {
      $self->add_type(%p);
    }

    if (defined $types{$p{name}}) {
      croak "Attempted to add type '$p{name}' that already exists";
    }

    my $type = clone(\%p);
    delete $type->{name};
    if (keys %$type == 0) {
      croak "No callbacks defined for type '$p{name}'";
    }
    $types{$p{name}} = $type;
    

    return;
  }

  sub add_type {
    my $self = shift;
    my %p = _parse_add_type_params(@_);
    
    if (defined $types[$$self]{$p{name}}) {
      croak "Attempted to add type '$p{name}' that already exists";
    }
    
    my $type = clone(\%p);
    delete $type->{name};
    if (keys %$type == 0) {
      croak "No callbacks defined for type '$p{name}'";
    }
    $types[$$self]{$p{name}} = $type;
    return;
  }

  sub reset_default_types {
    %types = %default_types;
    return;
  }

  sub _type_callback {
    my ($self, $callback, @args) = @_;

    while (my ($name, $value) = each %{ $types[$$self] }) {
      if (defined $value->{$callback}) {
        $value->{$callback}();
      }
    }
    return;
  }  

  # TODO: This should really be using Params::Validate, but when we
  # update it for that, it should check for the two argument form
  # explicitly, to maintain backwards compatibility.
  sub validate {
    my ($self, $cfg);

    croak "Config::Validate::validate requires two arguments" unless @_ == 2;

    if (blessed $_[0]) {
      ($self, $cfg) = @_;
    } else {
      my $schema;
      ($cfg, $schema) = @_;
      $self = Config::Validate->new(schema => $schema);
    }
    $cfg = clone($cfg);
    $self->_type_callback('init', $cfg);
    $self->_validate($cfg, $self->schema, []);
    $self->_type_callback('finish', $cfg);
    return $cfg;
  }

  sub _validate {
    my ($self, $cfg, $schema, $path) = @_;

    $schema = clone($schema);
    my $orig = clone($cfg);

    while (my ($canonical_name, $def) = each %$schema) {
      my @curpath = (@$path, $canonical_name);
      my @names = _get_aliases($canonical_name, $def, @curpath);
      $self->_check_definition_type($def, @curpath);

      my $found = 0;
      foreach my $name (@names) {
        next unless defined $cfg->{$name};
        
        if ($name ne $canonical_name) {
          $cfg->{$canonical_name} = $cfg->{$name};
          delete $cfg->{$name};
          delete $orig->{$name};
        }
        
        $self->_debug("Validating ", _mkpath(@curpath));
        if (lc($def->{type}) eq 'nested') {
          $self->_validate($cfg->{$canonical_name}, $schema->{$name}{child}, \@curpath);
        } else {
          $self->_invoke_validate_callback($cfg, $canonical_name, $def, \@curpath);
        }
        
        if (defined $def->{callback}) {
          if (ref $def->{callback} ne 'CODE') {
            croak sprintf("%s: callback specified is not a code reference", 
                        _mkpath(@curpath));
          }
          $def->{callback}($self, $cfg->{$canonical_name}, $def, \@curpath);
        }
        $found++;
      }
      
      if (not $found and defined $def->{default}) {
        $cfg->{$canonical_name} = $def->{default};
        $found++;
      }
      
      delete $orig->{$canonical_name};

      if (not $found and (not defined $def->{optional} or not $def->{optional})) {
        croak "Required item " . _mkpath(@curpath) . " was not found";
      }
    }

    my @unknown = sort keys %$orig;
    if (@unknown != 0) {
      croak sprintf("%s: the following unknown items were found: %s",
                  _mkpath($path), join(', ', @unknown));
    }
  }

  sub _invoke_validate_callback {
    my ($self, $cfg, $canonical_name, $def, $curpath) = @_;

    my $typeinfo = $types[$$self]{$def->{type}};
    my $callback = $typeinfo->{validate};

    if (not defined $callback) {
      croak("No callback defined for type '$def->{type}'");
    }
      
    if ($typeinfo->{byreference}) {
      $callback->($self, \$cfg->{$canonical_name}, $def, $curpath);
    } else {
      $callback->($self,  $cfg->{$canonical_name}, $def, $curpath);
    }
      
    return;
  }
  
  sub _get_aliases {
    my ($canonical_name, $definition, @curpath) = @_;
    
    my @names = ($canonical_name);
    if (defined $definition->{alias}) {
      if (ref $definition->{alias} eq 'ARRAY') {
        push(@names, @{$definition->{alias}});
      } elsif (ref $definition->{alias} eq '') {
        push(@names, $definition->{alias});
      } else {
        croak sprintf("Alias defined for %s is type %s, but must be " . 
                      "either an array reference, or scalar",
                      _mkpath(@curpath), ref $definition->{alias},
                     );
      }
    }
    return @names;
  }

  sub _check_definition_type {
    my ($self, $definition, @curpath) = @_;
    if (not defined $definition->{type}) {
      croak "No type specified for " . _mkpath(@curpath);
    }

    if (not defined $types[$$self]{$definition->{type}}) {
      croak "Invalid type '$definition->{type}' specified for ", 
        _mkpath(@curpath);
    }

    return;
  }

  sub _mkpath {
    @_ = @{$_[0]} if ref $_[0] eq 'ARRAY';
    
    return '[/' . join('/', @_) . ']';
  }

  sub _validate_hash {
    my ($self, $value, $def, $path) = @_;
    
    if (not defined $def->{keytype}) {
      croak "No keytype specified for " . _mkpath(@$path);
    }
    
    if (not defined $types[$$self]{$def->{keytype}}) {
      croak "Invalid keytype '$def->{keytype}' specified for " . _mkpath(@$path);
    }

    if (ref $value ne 'HASH') {
      croak sprintf("%s: should be a 'HASH', but instead is '%s'", 
                  _mkpath($path), ref $value);
    }

    while (my ($k, $v) = each %$value) {
      my @curpath = (@$path, $k);
      $self->_debug("Validating ", _mkpath(@curpath));
      my $callback = $types[$$self]{$def->{keytype}}{validate};
      $callback->($self, $k, $def, \@curpath);
      if ($def->{child}) {
        $self->_validate($v, $def->{child}, \@curpath);
      }
    }
    return;
  }

  sub _validate_array {
    my ($self, $value, $def, $path) = @_;
    
    if (not defined $def->{subtype}) {
      croak "No subtype specified for " . _mkpath(@$path);
    }

    if (not defined $types[$$self]{$def->{subtype}}) {
      croak "Invalid subtype '$def->{subtype}' specified for " . _mkpath(@$path);
    }
    
    if (ref $value eq 'SCALAR' and $array_allows_scalar[$$self]) {
      $$value = [ $$value ];
      $value = $$value;
    } elsif (ref $value eq 'REF' and ref $$value eq 'ARRAY') {
      $value = $$value;
    }

    if (ref $value ne 'ARRAY') {
      croak sprintf("%s: should be an 'ARRAY', but instead is a '%s'", 
                  _mkpath($path), ref $value);
    }

    foreach my $item (@$value) {
      $self->_debug("Validating ", _mkpath($path));
      my $callback = $types[$$self]{$def->{subtype}}{validate};
      $callback->($self, $item, $def, $path);
    }
    return;
  }

  sub _validate_integer {
    my ($self, $value, $def, $path) = @_;
    if ($value !~ /^ -? \d+ $/xo) {
      croak sprintf("%s should be an integer, but has value of '%s' instead",
                  _mkpath($path), $value);
    }
    if (defined $def->{max} and $value > $def->{max}) {
      croak sprintf("%s: %d is larger than the maximum allowed (%d)", 
                  _mkpath($path), $value, $def->{max});
    }
    if (defined $def->{min} and $value < $def->{min}) {
      croak sprintf("%s: %d is smaller than the minimum allowed (%d)", 
                  _mkpath($path), $value, $def->{max});
    }
  }

  sub _validate_float {
    my ($self, $value, $def, $path) = @_;
    if ($value !~ /^ -? \d*\.?\d+ $/xo) {
      croak sprintf("%s should be an float, but has value of '%s' instead",
                  _mkpath($path), $value);
    }
    if (defined $def->{max} and $value > $def->{max}) {
      croak sprintf("%s: %f is larger than the maximum allowed (%f)", 
                  _mkpath($path), $value, $def->{max});
    }
    if (defined $def->{min} and $value < $def->{min}) {
      croak sprintf("%s: %f is smaller than the minimum allowed (%f)", 
                  _mkpath($path), $value, $def->{max});
    }
  }

  sub _validate_string {
    my ($self, $value, $def, $path) = @_;
    
    if (defined $def->{maxlen}) {
      if (length($value) > $def->{maxlen}) {
        croak sprintf("%s: length of string is %d, but must be less than %d",
                    _mkpath($path), length($value), $def->{maxlen});
      }
    }
    if (defined $def->{minlen}) {
      if (length($value) < $def->{minlen}) {
        croak sprintf("%s: length of string is %d, but must be greater than %d",
                    _mkpath($path), length($value), $def->{minlen});
      }
    }
    if (defined $def->{regex}) {
      if ($value !~ $def->{regex}) {
        croak sprintf("%s: regex (%s) didn't match '%s'", _mkpath($path),
                    $def->{regex}, $value);
      }
    }
  }

  sub _validate_boolean {
    my ($self, $value, $def, $path) = @_;
    
    my @true  = qw(y yes t true on);
    my @false = qw(n no f false off);
    $value = 1 if grep { lc($value) eq $_ } @true;
    $value = 0 if grep { lc($value) eq $_ } @false;
    
    if ($value !~ /^ [01] $/x) {
      croak sprintf("%s: invalid value '%s', must be: %s", _mkpath($path),
                  $value, join(', ', (0, 1, @true, @false)));
    }
  }
  
  sub _validate_directory {
    my ($self, $value, $def, $path) = @_;

    if (not -d $value) {
      croak sprintf("%s: '%s' is not a directory", _mkpath($path), $value)
    }
    return;
  }
  
  sub _validate_file {
    my ($self, $value, $def, $path) = @_;

    if (not -f $value) {      
      croak sprintf("%s: '%s' is not a file", _mkpath($path), $value);
    }
    return;
  }

  sub _validate_domain {
    my ($self, $value, $def, $path) = @_;

    use Data::Validate::Domain qw(is_domain);
    
    my $rc = is_domain($value, { domain_allow_single_label => 1,
                                 domain_private_tld => qr/.*/x,
                                }
                      );
    return if $rc;

    croak sprintf("%s: '%s' is not a valid domain name.", _mkpath($path), $value);
  }
  
  sub _validate_hostname {
    my ($self, $value, $def, $path) = @_;

    use Data::Validate::Domain qw(is_hostname);
    
    my $rc = is_hostname($value, { domain_allow_single_label => 1,
                                   domain_private_tld => qr/\. acmedns $/xi,
                                  }
                      );
    return if $rc;

    croak sprintf("%s: '%s' is not a valid hostname.", _mkpath($path), $value);
  }

  sub _debug {
    my $self = shift;

    return unless $debug[$$self];
    return $on_debug[$$self]->($self, @_);    
  }

  sub debug_print {
    my $self = shift;

    print join('', @_), "\n";
    return;
  }

}
1;

__END__

=head1 NAME

Config::Validate - Validate data structures generated from configuration files.

=head1 VERSION

Version 0.02 

=head1 DESCRIPTION

This module is intended to be used to validate configuration data that
has been read in already and is in a Perl data structure.  It does not
handle reading or parsing configuration files since there are a
plethora of available modules on CPAN to do that task.  Instead if
concentrates on verifying that the data read is correct, and providing
defaults where appropriate.  It also allows you to specify that a
given configuration key may be available under several aliases, and
have those renamed to the canonical name automatically.

=head1 AUTHOR

Clayton O'Neill, E<lt>cpan3.20.coneill@xoxy.netE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007-2008 by Clayton O'Neill

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut

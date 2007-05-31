package Config::Validate;
{
  use Object::InsideOut;

  use strict;
  use warnings;
  use Data::Dumper;
  use Scalar::Util::Clone qw(clone);
  use UNIVERSAL qw(isa);
  use Params::Validate qw(validate_with :types);

  use Exporter qw(import);
  our @EXPORT_OK = qw(validate);
  our %EXPORT_TAGS = ('all' => \@EXPORT_OK);
  
  our $VERSION = '0.01';

=head1 NAME

Config::Validate - Validate data structures generated from configuration files.

=cut
  
  my @schema :Field :Accessor(schema) :Arg(schema);
  my @debug  :Field :Accessor(debug) :Arg(debug);
  my @types  :Field;

  my %default_types = (
    integer   => { validate => \&_validate_integer },
    string    => { validate => \&_validate_string },
    boolean   => { validate => \&_validate_boolean },
    hash      => { validate => \&_validate_hash }, 
    array     => { validate => \&_validate_array }, 
    directory => { validate => \&_validate_directory },
    file      => { validate => \&_validate_file },
    nested    => { validate => sub { die "'nested' is not valid here"; }},
  );

  sub _init :Init {
    my ($self, $args) = @_;
    
    $types[$$self] = clone(\%default_types);
    return;
  }

  sub _parse_add_type_params {
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
    shift if isa($_[0], 'Config::Validate');
    shift if defined $_ and $@[0] eq 'Config::Validate';

    my %p = _parse_add_type_params(@_);
    
    if (defined $default_types{$p{name}}) {
      die "Attempted to add type '$p{name}' that already exists";
    }
    
    my $type = clone(\%p);
    delete $type->{name};
    if (keys %$type == 0) {
      die "Attempted to define a type with no callbacks";
    }
    $default_types{$p{name}} = $type;
    return;
  }

  sub add_type {
    my $self = shift;
    my %p = _parse_add_type_params(@_);
    
    if (defined $types[$$self]{$p{name}}) {
      die "Attempted to add type '$p{name}' that already exists";
    }
    
    my $type = clone(\%p);
    delete $type->{name};
    if (keys %$type == 0) {
      die "Attempted to define a type with no callbacks";
    }
    $types[$$self]{$p{name}} = $type;
    return;
  }

  sub _type_callback {
    my ($self, $callback, @args) = @_;

    while (my ($name, $value) = each %{ $types[$$self] }) {
      if (defined $value->{$callback}) {
        $value->{$callback}();
      }
    }
  }

  sub validate {
    my ($self, $cfg);
    if (isa($_[0], 'Config::Validate')) {
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

    my $orig = clone($cfg);
    while (my ($canonical_name, $def) = each %$schema) {
      my @curpath = (@$path, $canonical_name);
      my @names = ($canonical_name);
      
      if (defined $def->{alias}) {
        if (ref $def->{alias} eq 'ARRAY') {
          push(@names, @{$def->{alias}});
        } elsif (ref $def->{alias} eq '') {
          push(@names, $def->{alias});
        } else {
          die sprintf("Alias defined for %s is type %s, but must be " . 
                      "either an array reference, or scalar",
                      _mkpath(@curpath), ref $def->{alias},
                     );
        }
      }
      
      my $found = 0;
      foreach my $name (@names) {
        if (not defined $def->{type}) {
          die "No type specified for " . _mkpath(@curpath);
        }
        
        if (not defined $types[$$self]{$def->{type}}) {
          die "Invalid type '$def->{type}' specified for " . _mkpath(@curpath);
        }
        
        next unless defined $cfg->{$name};
        
        if ($name ne $canonical_name) {
          $cfg->{$canonical_name} = $cfg->{$name};
          delete $cfg->{$name};
          delete $orig->{$name};
        }
        
        print "Validating ", _mkpath(@curpath), "\n" if $debug[$$self];
        if (lc($def->{type}) eq 'nested') {
          $self->_validate($cfg->{$canonical_name}, $schema->{$name}{child}, \@curpath);
        } else {
          my $callback = $types[$$self]{$def->{type}}{validate};
          $callback->($self, $cfg->{$canonical_name}, $def, \@curpath);
        }
        
        if (defined $def->{callback}) {
          if (ref $def->{callback} ne 'CODE') {
            die sprintf("%s: callback specified is not a code reference", 
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
        die "Required item " . _mkpath(@curpath) . " was not found";
      }
    }

    my @unknown = sort keys %$orig;
    if (@unknown != 0) {
      die sprintf("%s: the following unknown items were found: %s",
                  _mkpath($path), join(', ', @unknown));
    }
  }

  sub _mkpath {
    @_ = @{$_[0]} if ref $_[0] eq 'ARRAY';
    
    return '[/' . join('/', @_) . ']';
  }

  sub _validate_hash {
    my ($self, $value, $def, $path) = @_;
    
    if (not defined $def->{keytype}) {
      die "No keytype specified for " . _mkpath(@$path);
    }
    
    if (not defined $types[$$self]{$def->{keytype}}) {
      die "Invalid keytype '$def->{keytype}' specified for " . _mkpath(@$path);
    }
    
    while (my ($k, $v) = each %$value) {
      my @curpath = (@$path, $k);
      print "Validating ", _mkpath(@curpath), "\n" if $debug[$$self];
      my $callback = $types[$$self]{$def->{keytype}}{validate};
      $callback->($self, $k, $def, \@curpath);
      if ($def->{child}) {
        $self->_validate($v, $def->{child}, \@curpath);
      }
    }
  }

  sub _validate_array {
    my ($self, $value, $def, $path) = @_;
    
    if (not defined $def->{subtype}) {
      die "No subtype specified for " . _mkpath(@$path);
    }
    
    if (not defined $types[$$self]{$def->{subtype}}) {
      die "Invalid subtype '$def->{subtype}' specified for " . _mkpath(@$path);
    }
    
    foreach my $item (@$value) {
      print "Validating ", _mkpath($path), "\n" if $debug[$$self];
      my $callback = $types[$$self]{$def->{subtype}}{validate};
      $callback->($self, $item, $def, $path);
    }
  }

  sub _validate_integer {
    my ($self, $value, $def, $path) = @_;
    if ($value !~ /^ \d+ $/xo) {
      die sprintf("%s should be an integer, but has value of '%s' instead",
                  _mkpath($path), $value);
    }
    if (defined $def->{max} and $value > $def->{max}) {
      die sprintf("%s: %d is larger than the maximum allowed (%d)", 
                  _mkpath($path), $value, $def->{max});
    }
    if (defined $def->{min} and $value < $def->{min}) {
      die sprintf("%s: %d is smaller than the minimum allowed (%d)", 
                  _mkpath($path), $value, $def->{max});
    }
  }

  sub _validate_string {
    my ($self, $value, $def, $path) = @_;
    
    if (defined $def->{maxlen}) {
      if (length($value) > $def->{maxlen}) {
        die sprintf("%s: length of string is %d, but must be less than %d",
                    _mkpath($path), length($value), $def->{maxlen});
      }
    }
    if (defined $def->{minlen}) {
      if (length($value) < $def->{minlen}) {
        die sprintf("%s: length of string is %d, but must be greater than %d",
                    _mkpath($path), length($value), $def->{minlen});
      }
    }
    if (defined $def->{regex}) {
      if ($value !~ $def->{regex}) {
        die sprintf("%s: regex (%s) didn't match '%s'", _mkpath($path),
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
      die sprintf("%s: invalid value '%s', must be: %s", _mkpath($path),
                  $value, join(', ', (0, 1, @true, @false)));
    }
  }
  
  sub _validate_directory {
    my ($self, $value, $def, $path) = @_;

    if (not -d $value) {
      die sprintf("%s: '%s' is not a directory", _mkpath($path), $value)
    }
  }
  
  sub _validate_file {
    my ($self, $value, $def, $path) = @_;

    if (not -f $value and not -l $value) {
      die sprintf("%s: '%s' is not a file", _mkpath($path), $value)
    }
  }
  
}
1;

=head1 AUTHOR

Clayton O'Neill, E<lt>cpan3.20.coneill@xoxy.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Clayton O'Neill

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut

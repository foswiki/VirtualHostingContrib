# Contrib for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2010-2017 Foswiki Contributors.
# All Rights Reserved. TWiki Contributors and Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Contrib::VirtualHostingContrib::VirtualHost;

use File::Basename;
use Cwd;
our $CURRENT = undef;

BEGIN {
  if (!$Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir}) {
    my $path = Cwd::abs_path($Foswiki::cfg{DataDir} . '/../virtualhosts');
    $path =~ /(.*)$/; $path = $1; # untaint, we trust Foswiki configuration

    $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} = $path;
  }
}

sub find {
  my ($class, $hostname, $port) = @_;
  $hostname = _validate_hostname($hostname);
  return unless $hostname;

  # check whether the given virtual host directory exists or not
  if (!$class->exists($hostname)) {

    $hostname = $Foswiki::cfg{VirtualHostingContrib}{ServerAlias}{$hostname};
    return unless defined $hostname;
  }

  return unless $class->enabled($hostname);

  my $DataDir         = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . "/$hostname/data";
  my $WorkingDir      = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . "/$hostname/working";
  my $PubDir          = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . "/$hostname/pub";

  # Preserve http/https from DefaultUrlHost.   May be needed when ForceDefaultUrlHost active behind reverse proxy
  my ($protocol)      = $Foswiki::cfg{DefaultUrlHost} =~ m#^(https?://)#;
  my $VirtualUrlHost  = "$protocol$hostname" . ($port && ($port ne '80') && ($port ne '443') ? (':' . $port) : '');

  my $self            = {
    hostname => $hostname,
    directory => $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . "/$hostname",
    config => {
      DataDir               => $DataDir,
      PubDir                => $PubDir,
      WorkingDir            => $WorkingDir,
      DefaultUrlHost        => $VirtualUrlHost,
      # values defined in terms of DataDir
      Htpasswd => {
        FileName            => "$DataDir/.htpasswd",
      },
      Log => {
        Dir => $WorkingDir."/logs",
      },
      Cache => {
        RootDir => $WorkingDir."/cache",
      },
      RCS => {
        WorkAreaDir         => "$WorkingDir/work_areas",
      },
      TempfileDir           => "$WorkingDir/tmp",
    }
  };

  bless $self, $class;

  # Make sure configure is unusable by any host other than the DefaultUrlHost.
  # This change will persist under fcgi, so we need to restore it under the base host.
  if ( $VirtualUrlHost ne $Foswiki::cfg{DefaultUrlHost} ) {
      $Foswiki::cfg{Plugins}{ConfigurePlugin}{Enabled} = 0;
  }
  else {
      $Foswiki::cfg{Plugins}{ConfigurePlugin}{Enabled} = 1;
  }

  $self->{config}->{TemplatePath} = $self->_template_path();
  $self->_load_config();

  return $self;
}

sub hostname {
  my $self = shift;
  return $self->{hostname};
}

sub exists {
  my ($class, $hostname) = @_;
  return -d $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . "/$hostname/data";
}

sub enabled {
  my ($class, $hostname) = @_;

  unless (defined $class->{disabledServers}) {
    %{$class->{disabledServers}} = map {$_ => 1} split(/\s*,\s*/, $Foswiki::cfg{VirtualHostingContrib}{DisabledServers} || '');
  }

  return ! defined $class->{disabledServers}{$hostname};
}

sub run {
  my ($self, $code) = @_;

  local $Foswiki::Contrib::VirtualHostingContrib::VirtualHost::CURRENT = $self->hostname;

  local @Foswiki::cfg{keys %{$self->{config}}} = map { _merge_config($Foswiki::cfg{$_}, $self->{config}->{$_}) } (keys %{$self->{config}});

  &$code($self->hostname);
}

sub _merge_config {
  my ($global, $local)= @_;
  if (ref($global) eq 'HASH' && ref($local) eq 'HASH') {
    # merge hashes
    my %newhash = %{$global};
    for my $key (keys(%{$local})) {
      $newhash{$key} = _merge_config($global->{$key}, $local->{$key});
    }
    \%newhash;
  } else {
    $local;
  }
}

# StaticMethod
sub run_on_each {
  my ($class, $code) = @_;

  my @hostnames =
    grep { $class->exists($_) && $_ !~ /^_/ && !defined($Foswiki::cfg{VirtualHostingContrib}{ServerAlias}{$_}) }
    map { basename $_} glob($Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . '/*');

  for my $hostname (@hostnames) {
    my $virtual_host = $class->find($hostname);
    $virtual_host->run($code) if defined $virtual_host;
  }
}

# StaticMethod
sub run_on {
  my ($class, $hostname, $code) = @_;

  my $virtual_host = $class->find($hostname);

  die "ERROR: unknown virtual host $hostname" unless defined $virtual_host;

  $virtual_host->run($code);
}

sub _config {
  my ($self, $key) = @_;
  return $self->{config}->{$key} || $Foswiki::cfg{$key};
}

sub _validate_hostname {
  my $hostname = shift;
  return undef unless $hostname;
  if ($hostname =~ /^[\w-]+(\.[\w-]+)*$/) {
    return $&;
  } else {
    return undef;
  }
}

sub _template_path {
  my $self = shift;
  my $template_dir = $self->{directory} . '/templates';
  my @path = ();
  for my $component (split(/\s*,\s*/, $Foswiki::cfg{TemplatePath})) {
    if ($component =~ m/^\$Foswiki::cfg\{TemplateDir\}\/(.*)/ ||
      $component =~ m/^$Foswiki::cfg{TemplateDir}\/(.*)/) {
      my $relative_path = $1;
      # search in the virtual host templates directory
      push @path, "$template_dir/$relative_path";
    }
    # search in the system-wide templates
    push @path, $component;
  }
  return join(',', @path);
}

sub _load_config {
  my $self = shift;
  my $config_file = $self->{directory} . '/VirtualHost.cfg';
  if (-r $config_file) {
    my %VirtualHost;
    open CONFIG, $config_file;
    my @config = <CONFIG>;
    my $config = join('',@config);

    # untaint; we trust the virtual host configuration file
    $config =~ /(.*)/ms; $config = $1;

    # Replace $Foswiki::cfg with $VirtualHost, so that virtual hosts cannot
    # mess with the global configuration, even if they want to.
    $config =~ s/\$Foswiki::cfg/\$VirtualHost/g;

    eval $config;
    close CONFIG;
    for my $key (keys(%VirtualHost)) {
      $self->{config}->{$key} = $VirtualHost{$key};
    }
  }
}

1;

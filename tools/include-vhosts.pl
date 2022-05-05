#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;
use File::Spec;
use Cwd;

# calculate paths
my $foswiki_core = Cwd::abs_path( File::Spec->catdir( dirname(__FILE__), '..' ) );
chomp $foswiki_core;

unshift @INC, $foswiki_core . '/lib';
require Foswiki;
require Foswiki::Contrib::VirtualHostingContrib;

my $dir = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir};
$dir = Cwd::abs_path($dir);

my @virtualhosts = grep { -d $_ } grep {!/\/_/} glob("$dir/*");
push @virtualhosts, undef;

my %serverAliases = ();
my %disabledServers = map {$_ => 1} split(/\s*,\s*/, $Foswiki::cfg{VirtualHostingContrib}{DisabledServers} || '');

while (my ($key, $val) = each %{$Foswiki::cfg{VirtualHostingContrib}{ServerAlias}}) {
   $key =~ s/([\.\-])/\\$1/g;
   push @{$serverAliases{$val}}, $key;
}

for my $vhost (@virtualhosts) {
  next unless $vhost;
  my $hostname = basename($vhost);

  if ($disabledServers{$hostname}) {
    #print STDERR "... vhost $hostname is disabled\n";
    next;
  }

  print STDERR "... creating vhost $hostname\n";

  my $origHostname = $hostname;
  $hostname =~ s/([\.\-])/\\$1/g;
  my $aliases = $serverAliases{$origHostname} || [];
  my $pattern = '^('.join("|",($hostname, @{$aliases})).')$';

  my $redirectSettings = '';
  if ($Foswiki::cfg{VirtualHostingContrib}{RedirectToSSL} && $origHostname =~ /$Foswiki::cfg{VirtualHostingContrib}{RedirectToSSL}/) {
    $redirectSettings = <<'HERE';
  $HTTP["scheme"] == "http" {
    #url.redirect = ( "^/(.*)" => "https://" + server.name + "/$1" )
    url.redirect += ( 
      "^/((?:bin/)?(?:login).*)" => "https://" + server.name + "/$1",
      "^/(?:bin/view/)?(System/UserRegistration)" => "https://" + server.name + "/$1"
    )
  }
HERE
  }

  print <<HERE;
\$HTTP["host"] =~ "$pattern" {
  server.name = "$origHostname"
  server.document-root = vhostsdir + "/" + server.name + "/html"
$redirectSettings
  include "foswiki-base.conf"
}
HERE
}


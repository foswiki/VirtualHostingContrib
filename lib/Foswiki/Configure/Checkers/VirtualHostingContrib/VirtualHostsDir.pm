# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::VirtualHostingContrib::VirtualHostsDir;

use strict;
use warnings;

use Assert;
use Foswiki::Configure::Checkers::PATH ();
our @ISA = ('Foswiki::Configure::Checkers::PATH');

use Foswiki::Configure::FileUtil ();

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $d = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir};

    # SMELL: This is pretty much useless, when running under a virtual host,
    # as a BEGIN block forces this to be set. But useful when setting up under
    # a real foswiki instance.
    unless ( $d ) {
        $d = Cwd::abs_path( $Foswiki::cfg{DataDir} . '/../virtualhosts' );
        $d =~ /(.*)$/;
        $d = $1;    # untaint, we trust Foswiki configuration
    }

    $reporter->NOTE("Path =$d= is used for virtual hosts.");
    if ( $ENV{SCRIPT_FILENAME} && $ENV{SCRIPT_FILENAME} =~ m/virtualhosts\.fcgi$/ ) {
        $reporter->NOTE("   * *Caution* Configure is running under a virtual host.  Changing this setting on a live system may require an immediate restart.");
    }

    if ( -d $d ) {
        my $path   = $d . '/' . time;
        my $report = Foswiki::Configure::FileUtil::checkCanCreateFile($path);
        if ($report) {
            $reporter->ERROR("Cannot write to $d");
        }
    }
    elsif ( -e $d ) {
        $reporter->ERROR("$d Exists, but is not a directory");
    }
    else {
        $reporter->WARN("$d Does not exist.");
        return;
    }

    my @list;
    my $dh;

    if ( opendir( $dh, $d ) ) {
        @list = map {

            # Tradeoff: correct validation of every web name, which allows
            # non-web directories to be interleaved, thus:
            #    Foswiki::Sandbox::untaint(
            #           $_, \&Foswiki::Sandbox::validateWebName )
            # versus a simple untaint, much better performance:
            Foswiki::Sandbox::untaintUnchecked($_)
          }

          # The _e on the web preferences is used in preference to any
          # other mechanism for performance. Since the definition
          # of a Web in this store is "a directory with a
          # WebPreferences.txt in it", this works.
          grep { !/^\./ } readdir($dh);
        closedir($dh);
    }
    my $nhost = 0;
    if ( scalar @list ) {
        $reporter->NOTE("\n *Virtual Hosts:* ");
        foreach my $host ( sort @list ) {
            next if ( substr( $host, 0, 1 ) eq '_' );
            $reporter->NOTE(
                "   * $host "
                  . (
                    (
                        $Foswiki::cfg{VirtualHostingContrib}{DisabledServers}
                          =~ m/\b$host\b/
                    ) ? " *disabled* " : ''
                  )
            );
            $nhost++;
        }
        $reporter->NOTE("   * *No Virtual Hosts defined* ") unless $nhost;

        $reporter->NOTE(" *Template Hosts:* ");
        $nhost = 0;
        foreach my $host ( sort @list ) {
            next unless ( substr( $host, 0, 1 ) eq '_' );
            next if ( -f "$d/$host" );
            $reporter->NOTE("   * $host ");
            $nhost++;
        }
        $reporter->NOTE("<br/>&nbsp;&nbsp;No Template Hosts defined")
          unless $nhost;
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2015-2017 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

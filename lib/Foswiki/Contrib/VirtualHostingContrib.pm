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

package Foswiki::Contrib::VirtualHostingContrib;

use strict;
use warnings;

our $VERSION = '2.00';
our $RELEASE = '20 Jun 2017';

our $SHORTDESCRIPTION = 'Adds virtual hosting support for Foswiki.';

use Foswiki::Contrib::VirtualHostingContrib::VirtualHost;

BEGIN {
    no warnings 'redefine';

    *Foswiki::UI::handleRequest_implementation = \&Foswiki::UI::handleRequest;

    *Foswiki::UI::handleRequest = sub {
        my ($req) = shift;

        my $virtual_host =
          Foswiki::Contrib::VirtualHostingContrib::VirtualHost->find(
            $req->virtual_host(), $req->virtual_port() );

        if ($virtual_host) {

            # change the process name during the request
            local $0 = sprintf(
                "foswiki-virtualhost[%s%s]",
                $virtual_host->hostname(),
                $req->uri()
            );

            # serve under the virtual host
            $virtual_host->run(
                sub { Foswiki::UI::handleRequest_implementation($req); } );
        }
        else {
            # no virtual host: bail out
            my $res = new Foswiki::Response;
            $res->status(500);    # 500 - Virtual Host not found
            $res->header( -type => 'text/html', -charset => 'utf-8' );

            my $errmsg = <<'MORE';
<!DOCTYPE html>
<html>
  <head>
    <title>$hostname</title>
    <style type="text/css">
      body {
        font-family: arial,verdana,sans-serif;
        font-size: 14px;
        margin: auto 80px;
      }
      h1 {
        font-size: 170%;
        font-weight: normal;
        text-align: center;
        color: #2989BB;
      }
      blockquote {
        background-color:#F5F5F5;
        border-color:#DDDDDD;
        border-style:solid;
        border-width:1px 1px 1px 5px;
        padding:0.5em 1.25em;
      }
      code {
        color: black;
        font-weight: bold;
      }
    </style>
  </head>
  <body>
    <h1>Nothing to see here</h1>
    <blockquote>
      <p>
        We are sorry, but we could not find what you were looking for. There is
        no configuration for <code>$hostname</code> in our servers.
      </p>
      <p>
        It's possible that the <code>$hostname</code> site is under
        construction, and will be publicly available on some time.
      </p>
      <p>
        If you got here by following a link in another website, it would be
        nice if you notify its administrators that the link did not lead to a
        valid website.
      </p>
    </blockquote>
  </body>
</html>
MORE

            $errmsg =~ s/\$hostname/$req->virtual_host()/ge;
            $errmsg =~
s/\$logo/$Foswiki::cfg{PubUrlPath}\/System\/ProjectLogos\/foswiki-logo.png/g;
            $res->print($errmsg);

            return $res;
        }
      }
}

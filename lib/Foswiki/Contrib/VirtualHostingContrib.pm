# Contrib for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Contrib::VirtualHostingContrib;

use strict;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package. This should always be in the format
# $Rev: 3193 $ so that Foswiki can determine the checked-in status of the
# extension.
our $VERSION = '$Rev$';    # version of *this file*.

# $RELEASE is used in the "Find More Extensions" automation in configure.
# It is a manually maintained string used to identify functionality steps.
# You can use any of the following formats:
# tuple   - a sequence of integers separated by . e.g. 1.2.3. The numbers
#           usually refer to major.minor.patch release or similar. You can
#           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
# isodate - a date in ISO8601 format e.g. 2009-08-07
# date    - a date in 1 Jun 2009 format. Three letter English month names only.
# Note: it's important that this string is exactly the same in the extension
# topic - if you use %$RELEASE% with BuildContrib this is done automatically.
our $RELEASE = '0.4.0';

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
            $res->status(501);    # 501 Not Implemented
            $res->header( -type => 'text/html', -charset => 'utf-8' );
            while (<DATA>) {
                s/\$hostname/$req->virtual_host()/ge;
s/\$logo/$Foswiki::cfg{PubUrlPath}\/System\/ProjectLogos\/foswiki-logo.png/g;
                $res->print($_);
            }
            return $res;
        }
      }
}

__DATA__
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
    <img src="$logo" alt="Foswiki - VirtualHostingContrib" title="Foswiki - VirtualHostingContrib"/>
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

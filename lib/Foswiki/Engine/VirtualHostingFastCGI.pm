# Contrib for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2010-2022 Foswiki Contributors.
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

package Foswiki::Engine::VirtualHostingFastCGI;

use strict;
use warnings;

use Foswiki::Engine::FastCGI                             ();
use Foswiki::Contrib::VirtualHostingContrib::VirtualHost ();
our @ISA = qw( Foswiki::Engine::FastCGI );

sub handleRequest {
    my ( $this, $req ) = @_;

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
        return $virtual_host->run( sub { $this->SUPER::handleRequest($req); } );
    }

    # no virtual host: bail out
    my $res = new Foswiki::Response;
    $res->status(404);    # 404 - Virtual Host not found
    $res->header( -type => 'text/html', -charset => 'utf-8' );

    my $errmsg = <<'MORE';
<!DOCTYPE html>
<html>
<head>
<title>$hostname</title>
<style>
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

sub warmup {
    my ( $this, $manager ) = @_;

    Foswiki::Contrib::VirtualHostingContrib::VirtualHost->run_on_each(
        sub {
            $this->SUPER::warmup($manager);
        }
    );
}

1;

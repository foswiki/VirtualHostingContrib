#!/usr/bin/env perl

use strict;
use warnings;
use File::Basename;
use File::Spec;
use Cwd;
use Getopt::Long;
use Pod::Usage;

# defaults
my $port = 8080;

# calculate paths
my $foswiki_core = Cwd::abs_path( File::Spec->catdir( dirname(__FILE__), '..' ) );
chomp $foswiki_core;
my $conffile = $foswiki_core . '/working/tmp/virtualhosts-lightpd.conf';

unshift @INC, $foswiki_core . '/lib';
require Foswiki;
require Foswiki::Contrib::VirtualHostingContrib;

# command line options
my ( $fastcgi, $help );
GetOptions(
    'fastcgi|f'   => \$fastcgi,
    'help|h'      => \$help,
    'port|p=i'      => \$port,
);
pod2usage(1) if $help;

# write configuration file
open(CONF, '>', $conffile) or die("!! Cannot write configuration. Check write permissions to $conffile!");
print CONF "server.document-root = \"$foswiki_core\"\n";
print CONF  <<EOC
server.modules = (
    "mod_rewrite",
    "mod_alias",
    "mod_cgi",
    "mod_fastcgi"
)
server.port = $port
include_shell "/usr/share/lighttpd/create-mime.assign.pl"
url.rewrite-repeat = ( "^/?\$" => "/bin/view" )
EOC
;

my $dir = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir};

$dir = Cwd::abs_path($dir);
my @virtualhosts = grep { -d $_ } glob("$dir/*");
push @virtualhosts, undef;

for my $vhost (@virtualhosts) {

    if ($vhost) {
      my $hostname = basename($vhost);
      print CONF "
\$HTTP[\"host\"] == \"$hostname\" {

alias.url += ( \"/pub\" => \"$vhost/pub\" )

      ";
    }

if ($fastcgi) {
    print CONF "
\$HTTP[\"url\"] =~ \"^/bin/\" {
    alias.url += ( \"/bin\" => \"$foswiki_core/bin/virtualhosts.fcgi\" )
    fastcgi.server = ( \".fcgi\" => (
         (
            \"socket\"    => \"$foswiki_core/working/tmp/virtualhosts.sock\",
            \"bin-path\"  => \"$foswiki_core/bin/virtualhosts.fcgi\",
            \"max-procs\" => 1
         ),
      )
    )
}
    ";
} else {
    print CONF "
\$HTTP[\"url\"] =~ \"^/bin/\" {
    alias.url += ( \"/bin\" => \"$foswiki_core/bin/virtualhosts\" )
    cgi.assign = ( \"\" => \"\" )
}
    ";
}

# the configure script must always be run as CGI
print CONF "
\$HTTP[\"url\"] =~ \"^/bin/configure\" {
    alias.url += ( \"/bin/configure\" => \"$foswiki_core/bin/configure\" )
    cgi.assign = ( \"\" => \"\" )
}
";

    print CONF "}\n" if $vhost;

}

close(CONF);

# print banner
print "************************************************************\n";
print "Foswiki Development Server\n";
system('/usr/sbin/lighttpd -v 2>/dev/null');
print "Server root: $foswiki_core\n";
print "************************************************************\n";
print "Browse to http://localhost:$port/bin/configure to configure your Foswiki\n";
print "Browse to http://localhost:$port/bin/view to start testing your Foswiki checkout\n";
print "Hit Control-C at any time to stop\n";
print "************************************************************\n";


# execute lighttpd
system("/usr/sbin/lighttpd -f $conffile -D");

# finalize
system("rm -rf $conffile");

__END__

=head1 SYNOPSIS

vhost-lightpd.pl [options]

    Runs a lightpd instance with virtual hosting support.

    Options:
        -f --fastcgi               Use FastCGI instead of plain CGI
        -h --help                  Displays this help and exits
        -p PORT, --port PORT       Runs the server in the given port.
                                   (default: 8080)


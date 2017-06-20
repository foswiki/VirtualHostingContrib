# ---+ Extensions
# ---++ VirtualHostingContrib
# This is the configuration used by the <b>VirtualHostingContrib</b>. It sets
# the options for the Foswiki virtual hosting system.

# **PATH CHECK="emptyok perms:rD" FEEDBACK="icon='ui-icon-arrowrefresh-1-n';label='Create virtual host';wizard='CreateVHost';method='create_vhost_1'"**
# This is the directory in which your virtual hosts are stored. Must be
# readable and writable by the webserver user. If this path is empty,
# $FOSWIKI_ROOT/virtualhosts is used.
$Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} = '';

# **PERL**
# This is a mapping of alias names to existing virtual
# hosts. For example, if your foswiki instance running under localhost 
# should also be available under 127.0.0.1 and 192.168.10.1 then
# add the following two mappings to the ServerAlias:
# <code>'127.0.0.1' => 'localhost', '192.168.10.1' => 'localhost'</code>
$Foswiki::cfg{VirtualHostingContrib}{ServerAlias} = {
};

# **STRING 80**
# This is a list of servers that you'd like to disable even though there's a valid
# environment present in {VirtualHostsDir}. 
$Foswiki::cfg{VirtualHostingContrib}{DisabledServers} = '';

1;

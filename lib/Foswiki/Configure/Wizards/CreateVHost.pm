# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::CreateVHost;

use strict;
use warnings;

use Assert;

=begin TML

---+ package Foswiki::Configure::Wizards:CreateVHost

Prompt for a vhost name and create the host when
requested.

=cut

require Foswiki::Configure::Wizard;
our @ISA = ('Foswiki::Configure::Wizard');

use Foswiki::Func                  ();

# THE FOLLOWING MUST BE MAINTAINED CONSISTENT WITH Extensions.JsonReport
# They describe the format of an extension topic.


=begin TML

---+ WIZARD create_vhost_1

Stage 1 of the create wizard. Build a prompt page for the
virtual host to be created.

=cut

sub create_vhost_1 {
    my ( $this, $reporter ) = @_;

    $reporter->NOTE("---+ Create Virtual Host");
    $reporter->NOTE( '<form id="create_vhost">'
          . 'vhost name: '
          . '<input type="text" length="30" name="name"></input></br/>'
          . '</form>' );
    my %data = (
        wizard => 'CreateVHost',
        method => 'create_vhost_2',
        form   => '#create_vhost',
        args   => {

            # Other args come from the form
        }
    );
    $reporter->NOTE( $reporter->WIZARD( 'Create Vhost', \%data ) );
    return undef;
}

=begin TML

---+ WIZARD create_vhost_2

Stage 2 of the find extension process, follows on from find_extension_1.
Given a search, get matching extensions. the report will then permit
study and installation of the extensions.

=cut

sub create_vhost_2 {
    my ( $this, $reporter ) = @_;

    my $pa = $this->param('args');

    unless ( $pa->{name} ) {
        $reporter->ERROR("Site hostname required");
        return undef;
    }

    _create_vhost( $this, $reporter, $pa->{name} );

    $reporter->NOTE( "Done" );
    return undef;
}

sub _create_vhost {
    my ( $this, $reporter, $vhost ) = @_;

    my $vdir = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} || "$Foswiki::cfg{DataDir}/../virtualhosts";

    $reporter->ERROR("virtual host directory is missing") unless ( -e $vdir );

    if ( -e "$vdir/$vhost" ) {
        if ( -d "$vdir/$vhost" ) {
            $reporter->ERROR("Virtual host $vhost already exists.");
        } 
        else {
            $reporter->ERROR("Virtual host $vhost exists as a file. Unable to create.");
        }
        return 0;
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

create_skeleton() {
  echo "Creating skeleton for virtual host ..."
  mkdir -p "$VIRTUAL_HOSTS_DIR/$vhost/data"
  ln -s "$FOSWIKI_DATA_DIR/mime.types" "$VIRTUAL_HOSTS_DIR/$vhost/data/"
  mkdir -p "$VIRTUAL_HOSTS_DIR/$vhost/pub"
}

set_data_ownership() {
  user_group=$(stat -c %U:%G $FOSWIKI_DATA_DIR)
  echo "Setting data ownership to $user_group ..."
  chown -R "$user_group" "$VIRTUAL_HOSTS_DIR/$vhost/data/"
  chown -R "$user_group" "$VIRTUAL_HOSTS_DIR/$vhost/pub/"
  chown -R "$user_group" "$VIRTUAL_HOSTS_DIR/$vhost/working/"
}

copy_web() {
  web="$1"
  echo "Copying web $web ..."
  cp -r "$FOSWIKI_DATA_DIR/$web" "$VIRTUAL_HOSTS_DIR/$vhost/data/"
  if [ -d "$FOSWIKI_PUB_DIR/$web" ]; then
      cp -r "$FOSWIKI_PUB_DIR/$web" "$VIRTUAL_HOSTS_DIR/$vhost/pub/"
  fi
}

symlink_web(){
  web="$1"
  echo "Symlinking web $web ..."
  ln -s "$FOSWIKI_DATA_DIR/$web" "$VIRTUAL_HOSTS_DIR/$vhost/data/$web"
  if [ -d "$FOSWIKI_PUB_DIR/$web" ]; then
    ln -s "$FOSWIKI_PUB_DIR/$web" "$VIRTUAL_HOSTS_DIR/$vhost/pub/$web"
  fi
}

create_directories() {
  echo "Creating working directory ..."
  mkdir -p "$VIRTUAL_HOSTS_DIR/$vhost/working/tmp"
  mkdir -p "$VIRTUAL_HOSTS_DIR/$vhost/working/work_areas"
  mkdir -p "$VIRTUAL_HOSTS_DIR/$vhost/working/registration_approvals"
  mkdir -p "$VIRTUAL_HOSTS_DIR/$vhost/working/logs"
  echo "Deny from all" > "$VIRTUAL_HOSTS_DIR/$vhost/working/.htaccess"
  touch "$VIRTUAL_HOSTS_DIR/$vhost/data/.htpasswd"

  echo "Creating templates directory ..."
  mkdir -p "$VIRTUAL_HOSTS_DIR/$vhost/templates"
}

cleanup() {
  echo "Cleaning up the new virtual host directory ..."
  find "$VIRTUAL_HOSTS_DIR/$vhost" -type d -name .svn | xargs rm -rf
}

create_virtual_host_from_scratch(){
  create_skeleton
  copy_web    Main
  copy_web    Sandbox
  copy_web    Trash
  symlink_web System
  symlink_web _default
  symlink_web _empty
  create_directories
  cleanup
}

copy_virtualhost_template() {
  echo "Copying virtualhost template ..."
  cp -r "$VIRTUAL_HOSTS_DIR/_template" "$VIRTUAL_HOSTS_DIR/$vhost"
}

maybe_create_configuration_file() {
  echo "Creating configuration file from template ..."
  if [ -e "$VIRTUAL_HOSTS_DIR/_template.conf" ]; then
    sed -e "s/%VIRTUALHOST%/$vhost/g" "$VIRTUAL_HOSTS_DIR/_template.conf" > "$VIRTUAL_HOSTS_DIR/$vhost.conf"
    highlight "Configuration file created: $VIRTUAL_HOSTS_DIR/$vhost.conf"
  fi
}

highlight() {
  echo -e "\033[33;01m$1\033[m"
}

if [ -e "$VIRTUAL_HOSTS_DIR/_template" ]; then
  copy_virtualhost_template
else
  create_virtual_host_from_scratch
fi

set_data_ownership

maybe_create_configuration_file

highlight "Virtual host files in: $VIRTUAL_HOSTS_DIR/$vhost"



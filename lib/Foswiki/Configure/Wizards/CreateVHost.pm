# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::CreateVHost;

use strict;
use warnings;

use Assert;
use File::Copy;
use File::Copy::Recursive qw( dircopy );
use File::Path qw( make_path );

=begin TML

---+ package Foswiki::Configure::Wizards:CreateVHost

Prompt for a vhost name and create the host when
requested.

=cut

require Foswiki::Configure::Wizard;
our @ISA = ('Foswiki::Configure::Wizard');

use Foswiki::Func ();

# THE FOLLOWING MUST BE MAINTAINED CONSISTENT WITH Extensions.JsonReport
# They describe the format of an extension topic.

=begin TML

---+ WIZARD create_vhost_1

Stage 1 of the create wizard. Build a prompt page for the
virtual host to be created.

=cut

sub create_vhost_1 {
    my ( $this, $reporter ) = @_;

    my $vdir = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir};
    unless ($vdir) {
        $vdir = Cwd::abs_path( $Foswiki::cfg{DataDir} . '/../virtualhosts' );
        $vdir =~ /(.*)$/;
        $vdir = $1;    # untaint, we trust Foswiki configuration
    }

    my @templates;
    if ( opendir( my $dh, $vdir ) ) {
        @templates = map { Foswiki::Sandbox::untaintUnchecked($_) }
          grep { /^_/ } readdir($dh);
        closedir($dh);
    }

    my $form =
        '<form id="create_vhost">'
      . 'vhost name: '
      . '<input type="text" length="30" name="name"></input></br/>';
    $form .= 'Host Template name: <select name="template"> '
      . '<option selected value="-none-">-none-</option>';
    if ( scalar @templates ) {
        foreach my $template ( sort @templates ) {
            next unless ( -d "$vdir/$template" );
            $form .= "<option value='$template'>$template</option>";
        }
    }
    $form .= '</select><br/>';
    $form .= 'Config Template name: <select name="cfgtemplate"> '
      . '<option selected value="-none-">-none-</option>';
    if ( scalar @templates ) {
        foreach my $template ( sort @templates ) {
            next unless ( -f "$vdir/$template" );
            $form .= "<option value='$template'>$template</option>";
        }
    }
    $form .= '</select><br/>';

    $form .=
"Create .htpasswd file: <input type='checkbox' name='createpasswd' checked> (registration disabled if unchecked)<br/>";
    $form .= '</form>';

    $reporter->NOTE("---+ Create Virtual Host");
    $reporter->NOTE($form);
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

=cut

sub create_vhost_2 {
    my ( $this, $reporter ) = @_;

    my $args = $this->param('args');

    unless ( $args->{name} ) {
        $reporter->ERROR("Site hostname required");
        return undef;
    }

    $this->_create_vhost($reporter);

    $reporter->NOTE("\nDone");
    return undef;
}

sub _create_vhost {
    my ( $this, $reporter ) = @_;

    my $args = $this->param('args');

    my $vdir = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir};
    unless ($vdir) {
        $vdir = Cwd::abs_path( $Foswiki::cfg{DataDir} . '/../virtualhosts' );
        $vdir =~ /(.*)$/;
        $vdir = $1;    # untaint, we trust Foswiki configuration
    }

    $args->{vdir} = $vdir;
    my $vhost       = $args->{name};
    my $template    = $args->{template};
    my $cfgtemplate = $args->{cfgtemplate};

    $reporter->ERROR("virtual host directory is missing") unless ( -e $vdir );

    if ( -e "$vdir/$vhost" ) {
        if ( -d "$vdir/$vhost" ) {
            $reporter->ERROR("Virtual host $vhost already exists.");
        }
        else {
            $reporter->ERROR(
                "Virtual host $vhost exists as a file. Unable to create.");
        }
        return 0;
    }

    if ( $template && -d "$vdir/$template" ) {
        $this->_createFromTemplate($reporter);
    }
    else {
        $this->_createFromScratch($reporter);
    }

    if ( $cfgtemplate && -f "$vdir/$cfgtemplate" ) {
        $this->_createConfigFile($reporter);
    }

    if ( $args->{createpasswd} ) {
        _create_htpasswd( $reporter,
            "$args->{vdir}/$args->{name}/data/.htpasswd" );
    }

    unless ( -e "$args->{vdir}/$args->{name}/data/.htpasswd" ) {
        $reporter->WARN(
            "No =.htpasswd= file exists. Registration id disabled.");
    }

    $this->_setPermissions($reporter);
}

sub _createFromTemplate {
    my $this     = shift;
    my $reporter = shift;
    my $args     = $this->param('args');

    my ( $num_of_files_and_dirs, $num_of_dirs, $depth_traversed ) =
      dircopy( "$args->{vdir}/$args->{template}",
        "$args->{vdir}/$args->{name}" );

    $reporter->NOTE("   * Created =$args->{name}=.");
    $reporter->NOTE(
"   * copied: $num_of_files_and_dirs files and directories from =$args->{template}=."
    );

    return;
}

sub _createConfigFile {
    my $this     = shift;
    my $reporter = shift;
    my $args     = $this->param('args');

    if ( -f "$args->{vdir}/$args->{cfgtemplate}" ) {
        my $cfg = _readFile("$args->{vdir}/$args->{cfgtemplate}");
        $cfg =~ s/%VIRTUALHOST%/$args->{name}/g;
        _saveFile( "$args->{vdir}/$args->{name}/$args->{name}.conf", $cfg );
        $reporter->NOTE(
            "   * Saved =$args->{vdir}/$args->{name}/$args->{name}.conf=");
    }
    return;
}

sub _createFromScratch {
    my $this     = shift;
    my $reporter = shift;
    my $args     = $this->param('args');

    $reporter->NOTE(
        "   * Create for =$args->{name}= in directory =$args->{vdir}=");

    File::Path::make_path("$args->{vdir}/$args->{name}/data");
    _symlink_or_copy(
        "$Foswiki::cfg{DataDir}/mime.types",
        "$args->{vdir}/$args->{name}/data/mime.types"
    );
    File::Path::make_path("$args->{vdir}/$args->{name}/pub");

    $this->_copy_web( $Foswiki::cfg{UsersWebName} );
    $this->_copy_web( $Foswiki::cfg{SandboxWebName} );
    $this->_copy_web( $Foswiki::cfg{TrashWebName} );

    $this->_link_web( $Foswiki::cfg{SystemWebName} );
    $this->_link_web('_default');
    $this->_link_web('_empty');

    File::Path::make_path("$args->{vdir}/$args->{name}/working/tmp");
    File::Path::make_path("$args->{vdir}/$args->{name}/working/work_areas");
    File::Path::make_path(
        "$args->{vdir}/$args->{name}/working/registration_approvals");
    File::Path::make_path("$args->{vdir}/$args->{name}/working/logs");
    File::Path::make_path("$args->{vdir}/$args->{name}/templates");

    return;
}

sub _setPermissions {
    return;
}

sub _copy_web {
    my $this = shift;
    my $web  = shift;
    my $args = $this->param('args');

    File::Copy::Recursive::dircopy( "$Foswiki::cfg{DataDir}/$web",
        "$args->{vdir}/$args->{name}/data/$web" );
    File::Copy::Recursive::dircopy( "$Foswiki::cfg{PubDir}/$web",
        "$args->{vdir}/$args->{name}/pub/$web" )
      if ( -d "$Foswiki::cfg{PubDir}/$web" );
}

sub _link_web {
    my $this = shift;
    my $web  = shift;
    my $args = $this->param('args');

    _symlink_or_copy( "$Foswiki::cfg{DataDir}/$web",
        "$args->{vdir}/$args->{name}/data/$web" );
    _symlink_or_copy( "$Foswiki::cfg{PubDir}/$web",
        "$args->{vdir}/$args->{name}/pub/$web" )
      if ( -d "$Foswiki::cfg{PubDir}/$web" );
}

sub _readFile {
    my ($fn) = @_;
    my $F;

    if ( open( $F, '<:encoding(utf-8)', $fn ) ) {
        local $/;
        my $text = <$F>;
        close($F);

        return $text;
    }
    else {
        return undef;
    }
}

sub _saveFile {
    my ( $name, $text ) = @_;
    my $FILE;
    unless ( open( $FILE, '>', $name ) ) {
        die "Can't create file $name - $!\n";
    }
    binmode $FILE, ':encoding(utf-8)';
    print $FILE $text;
    close($FILE);
}

sub _symlink_or_copy {
    my ( $from, $to ) = @_;

    my $symlink = eval { symlink( "", "" ); 1 };

    if ($symlink) {
        symlink( $from, $to );
    }
    else {
        dircopy( $from, $to );
    }
}

sub _create_htpasswd {
    my $reporter = shift;
    my $f        = shift;
    my $fh;

    if ( !open( $fh, ">", $f ) || !close($fh) ) {
        return $reporter->ERROR(
            "Password file $f does not exist and could not be created: $!");
    }
    else {
        $reporter->NOTE("   * A new password file =$f= has been created.");
    }

    if ( -e $f ) {
        unless ( chmod( 0600, $f ) ) {
            $reporter->WARN(
                "Permissions could not be changed on the password file =$f=" );
        }
    }
}
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2017 Foswiki Contributors. Foswiki Contributors
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


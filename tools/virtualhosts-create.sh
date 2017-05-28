#!/bin/sh

set -e

vhost="$1"
if [ -z "$vhost" ]; then
  echo "usage: $0 <vhostname>"
  exit 1
fi

FOSWIKI_HOME="$(dirname $0)/.."
VIRTUAL_HOSTS_DIR=$(perl -I${FOSWIKI_HOME}/lib -I/etc/foswiki -MFoswiki -MFoswiki::Contrib::VirtualHostingContrib -e 'print $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir}')
FOSWIKI_DATA_DIR=$(perl -I${FOSWIKI_HOME}/lib -I/etc/foswiki -MFoswiki -e 'print $Foswiki::cfg{DataDir}')
FOSWIKI_PUB_DIR=$(perl -I${FOSWIKI_HOME}/lib -I/etc/foswiki -MFoswiki -e 'print $Foswiki::cfg{PubDir}')

if [ -z "$VIRTUAL_HOSTS_DIR" ] || [ ! -d "$VIRTUAL_HOSTS_DIR" ] ; then
  echo "Virtual host directory \"$VIRTUAL_HOSTS_DIR\" is invalid or does not exist!"
  exit 1
fi

if [ -d "$VIRTUAL_HOSTS_DIR/$vhost" ]; then
  echo "Virtual host $vhost already exists!"
  exit 1
fi

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

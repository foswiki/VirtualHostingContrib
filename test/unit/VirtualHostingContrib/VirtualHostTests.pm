package VirtualHostTests;

use strict;
use Error qw(:try);
use Foswiki::Contrib::VirtualHostingContrib::VirtualHost;

our $ROOT = '/tmp/foswiki-virtualhosts';

use base qw( FoswikiTestCase );

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub set_up {
  my $this = shift;

  $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} = $ROOT;
  $Foswiki::cfg{VirtualHostingContrib}{DisabledServers} = 'disabled1.com, disabled2.com';

  mkdir($ROOT);

  $this->SUPER::set_up();
}

sub tear_down {
  system("rm -rf $ROOT");
}

sub create_vhost {
  my $hostname = shift || 'default';

  # create structure
  mkdir("$ROOT/$hostname");
  mkdir("$ROOT/$hostname/data");

  return Foswiki::Contrib::VirtualHostingContrib::VirtualHost->find($hostname);
}

sub create_config {
  my ($hostname, %config) = @_;
  $hostname ||= 'default';
  mkdir("$ROOT/$hostname");
  open OUT, ">$ROOT/$hostname/VirtualHost.cfg" or die ($!);
  for my $key (keys %config) {
    print OUT _dump_config('$VirtualHost', $key, %config);
  }
  close OUT;
}

sub create_config_with_content {
  my ($hostname, $text) = @_;
  $hostname ||= 'default';
  mkdir("$ROOT/$hostname");
  open OUT, ">$ROOT/$hostname/VirtualHost.cfg" or die ($!);
  print OUT $text;
  close OUT;
}

sub _dump_config {
  my ($prefix, $key, %config) = @_;
  if (ref($config{$key}) eq 'HASH') {
    join('', map { _dump_config("${prefix}{$key}", $_, %{$config{$key}}) } keys(%{$config{$key}}));
  } else {
    my $dumper = Data::Dumper->new([$config{$key}]);
    $dumper->Terse(1)->Indent(0);
    sprintf("${prefix}{$key} = %s;\n", $dumper->Dump());
  }
}

sub test_config {
  my $this = shift;
  my $vhost = create_vhost();
  for my $key (qw(DataDir PubDir WorkingDir DefaultUrlHost)) {
    $this->assert($vhost->_config($key), "$key must be present");
  }
}

sub test_existing_vhost {
  my $this = shift;

  create_vhost("lala.com");
  my $vhost = Foswiki::Contrib::VirtualHostingContrib::VirtualHost->find('lala.com');

  $this->assert($vhost->_config('DataDir') eq "$ROOT/lala.com/data");
  $this->assert($vhost->_config('PubDir') eq "$ROOT/lala.com/pub");
  $this->assert($vhost->_config('WorkingDir') eq "$ROOT/lala.com/working");
  $this->assert($vhost->_config('DefaultUrlHost') eq "http://lala.com");
}

sub test_unexisting_vhost {
  my $this = shift;
  my $vhost = Foswiki::Contrib::VirtualHostingContrib::VirtualHost->find('unexisting.com');
  $this->assert(!$vhost, "searching for an unexisting virtualhost must return nothing");
}

sub test_disabled_vhost {
  my $this = shift;

  create_vhost('disabled1.com');
  create_vhost('disabled2.com');
  create_vhost('enabled.com');

  my $vhost = Foswiki::Contrib::VirtualHostingContrib::VirtualHost->find('disabled1.com');
  $this->assert(!$vhost, "searching for a disabled virtualhost must return nothing");

  $vhost = Foswiki::Contrib::VirtualHostingContrib::VirtualHost->find('disabled2.com');
  $this->assert(!$vhost, "searching for a disabled virtualhost must return nothing");

  $vhost = Foswiki::Contrib::VirtualHostingContrib::VirtualHost->find('enabled.com');
  $this->assert($vhost, "searching for an enabled virtualhost must return something");
}

sub test_find_with_invalid_hostname {
  my $this = shift;
  my $vhost = Foswiki::Contrib::VirtualHostingContrib::VirtualHost->find('../../../../../../etc/passwd');
  $this->assert(!defined $vhost, "trying invalid hostname must return no virtualhost at all");
}

sub test_validate_hostanme {
  my $this = shift;
  my @valid_list = qw(
    www.bli.com.br
    bli.com.br
    bla.org
    bla.net
    www.bla.net
    with-dashes.com
    www-2.with-dashes.com
    123.com
    127.0.0.1
    11.22.33.44
    singlename
  );
  my @invalid_list = (
    undef,
    '../../../../../../../../../etc/passwd',
    'bli.com|ble',
    '|ssh zoombiehost.com',
    'ssh zoombiehost.com|',
  );

  for my $valid (@valid_list) {
    $this->assert(Foswiki::Contrib::VirtualHostingContrib::VirtualHost::_validate_hostname($valid) eq $valid, "$valid must be valid");
  }
  for my $invalid (@invalid_list) {
    $this->assert(!defined Foswiki::Contrib::VirtualHostingContrib::VirtualHost::_validate_hostname($invalid), ($invalid || '(undef)') . " must be invalid");
  }
}

sub test_local_setting_of_variables {
  my $this = shift;
  my $vhost = create_vhost('example.com');

  foreach my $config (qw(DataDir PubDir WorkingDir DefaultUrlHost TemplatePath)) {
    my $default = $Foswiki::cfg{$config};
    my $inside = $vhost->run(sub { $Foswiki::cfg{$config} });
    $this->assert(defined $inside, "must define $config inside virtual host");
    $this->assert($inside ne $default, "must change $config when running inside virtual host (default: $default)");
  }
}

sub test_modified_TemplatePath {
  my $this = shift;
  my $vhost = create_vhost('example.com');
  my $original_TemplatePath = $Foswiki::cfg{TemplatePath};
  my $modified_TemplatePath = $vhost->run(sub { $Foswiki::cfg{TemplatePath}});

  my @modified_path = split(/\s*,\s*/, $modified_TemplatePath);
  for my $component (split(/\s*,\s*/, $original_TemplatePath)) {
    $this->assert(grep { $_ eq $component } @modified_path, "component $component from original TemplatePath must be kept");
  }
}

sub test_virtualhost_template_path {
  my $this = shift;
  my $vhost = create_vhost('example.com');
  my @path = split(/\s*,\s*/, $vhost->_template_path());

  $this->assert(grep { $_ eq "$ROOT/example.com/templates/\$web/\$name.\$skin.tmpl" } @path, 'must add virtualhost templates to TemplatePath (web/topic)');
  $this->assert(grep { $_ eq "$ROOT/example.com/templates/\$name.\$skin.tmpl" } @path, 'must add virtualhost templates to TemplatePath (name/skin)');
  $this->assert(grep { $_ eq "$ROOT/example.com/templates/\$web/\$name.tmpl" } @path, 'must add virtualhost templates to TemplatePath (web/skin)');
  $this->assert(grep { $_ eq "$ROOT/example.com/templates/\$name.tmpl" } @path, 'must add virtualhost templates to TemplatePath (name)');
}

sub test_custom_WebNames {
  my $this = shift;
  for my $config ('SystemWebName', 'UsersWebName', 'TrashWebName') {
    my $orig = $Foswiki::cfg{$config};

    # not set
    my $vhost = create_vhost('example.com');
    my $vhost_value = $vhost->run(sub { $Foswiki::cfg{$config} });
    $this->assert_str_equals($orig, $vhost_value, "use default when not set");

    # set
    create_config('example2.com', $config => 'Custom');
    my $vhost2 = create_vhost('example2.com');
    $vhost_value = $vhost2->run(sub { $Foswiki::cfg{$config} });
    $this->assert_str_equals('Custom', $vhost_value, "setting $config");
  }
}

sub test_reading_config_file {
  my $this = shift;
  create_config('example.com', 'setting1' => 'value1', 'setting2' => 'value2');
  my $vhost = create_vhost('example.com');
  $this->assert_str_equals('value1', $vhost->_config('setting1'));
  $this->assert_str_equals('value2', $vhost->_config('setting2'));
}

sub test_reading_config_file_with_Foswiki_cfg_reference {
  my $this = shift;
  create_config_with_content('example.com', '$Foswiki::cfg{SomeSetting} = "SomeValue"; 1;');
  my $vhost = create_vhost('example.com');
  $this->assert_str_equals('SomeValue', $vhost->run(sub { $Foswiki::cfg{'SomeSetting'};}));
  $this->assert_null($Foswiki::cfg{'SomeSetting'});
}

sub test_run_on_each {
  my $this = shift;
  create_vhost('example.com');
  create_vhost('colivre.coop.br');
  my @list = ();
  Foswiki::Contrib::VirtualHostingContrib::VirtualHost->run_on_each(sub {
      push @list, $Foswiki::cfg{DataDir};
    }
  );
  @list = sort @list;
  my @expected = ("$ROOT/colivre.coop.br/data", "$ROOT/example.com/data");
  $this->assert_deep_equals(\@expected, \@list, 'must run a block inside each virtual host')
}

sub test_run_on {
  my $this = shift;
  create_vhost('example.com');
  my @list = ();
  Foswiki::Contrib::VirtualHostingContrib::VirtualHost->run_on('example.com', sub {
      push @list, $Foswiki::cfg{DataDir};
    }
  );
  @list = sort @list;
  my @expected = ("$ROOT/example.com/data");
  $this->assert_deep_equals(\@expected, \@list, 'must run a block inside a virtual host')
}

sub test_run_on_alias {
  my $this = shift;

  create_vhost('example.com');
  $Foswiki::cfg{VirtualHostingContrib}{ServerAlias}{'example'} = 'example.com';

  my @list = ();
  Foswiki::Contrib::VirtualHostingContrib::VirtualHost->run_on('example', sub {
      push @list, $Foswiki::cfg{DataDir};
    }
  );

  my $error;
  try {
    Foswiki::Contrib::VirtualHostingContrib::VirtualHost->run_on('unknown', sub {
        push @list, $Foswiki::cfg{DataDir};
      }
    );
  } catch Error::Simple with {
    $error = shift;
  };

  $this->assert(defined($error));

  @list = sort @list;
  my @expected = ("$ROOT/example.com/data");
  $this->assert_deep_equals(\@expected, \@list, 'must run a block inside a virtual host')
}


sub test_run_on_each_ignores_template {
  my $this = shift;
  create_vhost('_template');
  Foswiki::Contrib::VirtualHostingContrib::VirtualHost->run_on_each(sub { die('must never run') });
}

sub test_run_on_each_ignores_file {
  my $this = shift;
  open OUT, ">$ROOT/test" or die ($!);
  print OUT "a file must not be considered as a virtual host dir ...";
  close OUT;
  Foswiki::Contrib::VirtualHostingContrib::VirtualHost->run_on_each(sub { die('must never run') });
}

sub test_CURRENT_is_undef {
  my $this = shift;
  $this->assert(!defined($Foswiki::Contrib::VirtualHostingContrib::VirtualHost::CURRENT));
}

sub test_run_sets_CURRENT {
  my $this = shift;
  my $vhost = create_vhost('example.com');
  my $current = $vhost->run(sub { $Foswiki::Contrib::VirtualHostingContrib::VirtualHost::CURRENT });
  $this->assert_str_equals('example.com', $current);
}

sub test_CURRENT_gets_reset_after_run {
  my $this = shift;
  my $vhost = create_vhost('example.com');
  $vhost->run(sub { });
  $this->assert(!defined($Foswiki::Contrib::VirtualHostingContrib::VirtualHost::CURRENT));
}

sub test_redefine_JSCalendarContrib_style_configuration {
  my $this = shift;
  my $orig = $Foswiki::cfg{JSCalendarContrib}->{style};

  # not set
  my $vhost = create_vhost('example.com');
  my $vhost_value = $vhost->run(sub { $Foswiki::cfg{JSCalendarContrib}->{style} });
  $this->assert_equals($orig, $vhost_value, "use default when not set");

  # set
  create_config('paulofreire.org', JSCalendarContrib => {style => 'brown'});
  my $vhost2 = create_vhost('paulofreire.org');
  my $jscalendarcontrib_value = $vhost2->run(sub { $Foswiki::cfg{JSCalendarContrib}->{style} });
  $this->assert_str_equals('brown', $jscalendarcontrib_value, "setting JSCalendarContrib style");
}

sub test_redefine_JSCalendarContrib_lang_configuration {
  my $this = shift;
  my $orig = $Foswiki::cfg{JSCalendarContrib}->{lang};

  # not set
  my $vhost = create_vhost('example.com');
  my $vhost_value = $vhost->run(sub { $Foswiki::cfg{JSCalendarContrib}->{lang} });
  $this->assert_equals($orig, $vhost_value, "use default when not set");

  # set
  create_config('paulofreire.org', JSCalendarContrib => {lang => 'pt'});
  my $vhost2 = create_vhost('paulofreire.org');
  my $jscalendarcontrib_value = $vhost2->run(sub { $Foswiki::cfg{JSCalendarContrib}->{lang} });
  $this->assert_str_equals('pt', $jscalendarcontrib_value, "setting JSCalendarContrib lang");
}

sub test_set_arbitrary_configurations {
  my $this = shift;
  create_vhost('example.com');
  create_config('example.com', SomeSetting => 'NewValue');

  my $vhost = Foswiki::Contrib::VirtualHostingContrib::VirtualHost->find('example.com');
  $this->assert_str_equals('NewValue', $vhost->run(sub { $Foswiki::cfg{SomeSetting} }));
}

sub test_set_arbitrary_configurations_with_hashes {
  my $this = shift;
  $Foswiki::cfg{SomePlugin}{UnchangedSetting} = 'Unchanged';

  create_vhost('example.com');
  create_config('example.com', 'SomePlugin' => { Setting1 => 'Value1', Setting2 => 'Value2'});

  my $vhost = Foswiki::Contrib::VirtualHostingContrib::VirtualHost->find('example.com');

  $this->assert_str_equals('Value1', $vhost->run(sub { $Foswiki::cfg{SomePlugin}{Setting1}}));
  $this->assert_str_equals('Value2', $vhost->run(sub { $Foswiki::cfg{SomePlugin}{Setting2}}));
  $this->assert_str_equals('Unchanged', $vhost->run(sub { $Foswiki::cfg{SomePlugin}{UnchangedSetting}}));
}

sub test_set_arbitrary_configurations_with_nested_hashes {
  my $this = shift;

  $Foswiki::cfg{Languages}{pt}{Enabled} = 0;
  $Foswiki::cfg{Languages}{pt}{SomeSetting} = 0;
  $Foswiki::cfg{Languages}{fr}{Enabled} = 0;
  $Foswiki::cfg{Languages}{fr}{SomeSetting} = 0;

  create_vhost('example.com');
  my %cfg;
  $cfg{Languages}{pt}{Enabled} = 1;
  $cfg{Languages}{fr}{SomeSetting} = 1;
  create_config('example.com', %cfg);

  my $vhost = Foswiki::Contrib::VirtualHostingContrib::VirtualHost->find('example.com');

  $this->assert_equals(1, $vhost->run(sub { $Foswiki::cfg{Languages}{pt}{Enabled}; }));
  $this->assert_equals(0, $vhost->run(sub { $Foswiki::cfg{Languages}{pt}{SomeSetting}; }));
  $this->assert_equals(0, $vhost->run(sub { $Foswiki::cfg{Languages}{fr}{Enabled}; }));
  $this->assert_equals(1, $vhost->run(sub { $Foswiki::cfg{Languages}{fr}{SomeSetting}; }));
}

sub test_merge_config {
  my $this = shift;
  my $merge = \&Foswiki::Contrib::VirtualHostingContrib::VirtualHost::_merge_config;

  $this->assert_deep_equals({}, &$merge({}, {}));
  $this->assert_deep_equals({ X => 2 }, &$merge({ X => 1 }, { X => 2 }));
  $this->assert_deep_equals({ X => { X1 => 1, X2 => 2 } }, &$merge({ X => { X1 => 0 } }, { X => => { X1 => 1, X2 => 2} }));
  $this->assert_deep_equals({ X => 1}, &$merge(1, { X => 1}));
  $this->assert_deep_equals(1, &$merge({ X => 1}, 1));

  my %global = (); $global{Languages}{pt}{Enabled} = 0;
  my %local = (); $local{Languages}{pt}{Enabled} = 1;
  my $merged = &$merge($global{Languages}, $local{Languages});
  $this->assert_equals(1, $merged->{pt}{Enabled});
}


1;

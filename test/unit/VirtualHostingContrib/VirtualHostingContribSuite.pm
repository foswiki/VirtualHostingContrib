package VirtualHostingContribSuite;

use strict;
use Unit::TestSuite;
our @ISA = 'Unit::TestSuite';

sub name { 'VirtualHostingContribSuite' }

sub include_tests { return 'VirtualHostTests' }

1;

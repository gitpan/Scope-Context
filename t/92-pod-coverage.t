#!perl -T

use strict;
use warnings;

use Test::More;

use lib 't/lib';
use VPIT::TestHelpers;

load_or_skip_all('Test::Pod::Coverage', '1.08', [ ]);
load_or_skip_all('Pod::Coverage',       '0.18'     );

eval 'use Test::Pod::Coverage'; # Make Kwalitee test happy

all_pod_coverage_ok( { also_private => [ qr/^_/, qr/^CLONE(_SKIP)?$/ ] } );

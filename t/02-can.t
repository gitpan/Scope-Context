#!perl -T

use strict;
use warnings;

use Test::More;

my @methods = qw<
 new here
 cxt
 uid is_valid assert_valid
 want
 up sub eval
 reap localize localize_elem localize_delete unwind uplevel
>;

plan tests => scalar(@methods);

require Scope::Context;

for (@methods) {
 ok(Scope::Context->can($_), 'Scope::Context objects can ' . $_);
}


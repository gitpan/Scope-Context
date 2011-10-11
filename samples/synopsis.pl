#!perl

use strict;
use warnings;

use blib;

use Scope::Context;

for my $run (1 .. 2) {
 my @values = sub {
  local $@;

  eval {
   # create Scope::Context objects
   my ($block, $sub, $eval, $loop);
   {
    $block = Scope::Context->new;
    $sub   = $block->sub;    # = $block->up
    $eval  = $block->eval;   # = $block->up(2)
    $loop  = $eval->up;      # = $block->up(3)
   }

   eval {
    # This will throw an exception, since $block has expired.
    $block->localize('$x' => 1);
   };
   print "Caught an error at run $run: $@" if $@;

   # This prints "hello" when the eval block above ends.
   $eval->reap(sub { print "End of eval scope at run $run\n" });

   # Ignore $SIG{__DIE__} just for the loop.
   $loop->localize_delete('%SIG', '__DIE__');

   # Execute the callback as if it ran in place of the sub.
   my @values = $sub->uplevel(sub {
    return @_, 2;
   }, 1);

   # Immediately return (1, 2, 3) from the sub, bypassing the eval.
   $sub->unwind(@values, 3);

   # Not reached.
   return 'XXX';
  };

  # Not reached.
  die $@ if $@;
 }->();

 print "Values returned at run $run: @values\n";
}

package Scope::Context;

use 5.006;

use strict;
use warnings;

use Carp         ();
use Scalar::Util ();

use Scope::Upper 0.18 ();

=head1 NAME

Scope::Context - Object-oriented interface for inspecting or acting upon upper scope frames.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Scope::Context;

    for (1 .. 5) {
     sub {
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

       # This prints "hello" when the eval block above ends.
       $eval->reap(sub { print "hello\n" });

       # Ignore $SIG{__DIE__} just for the loop.
       $loop->localize_delete('%SIG', '__DIE__');

       # Execute the callback as if it ran in place of the sub.
       my @values = $sub->uplevel(sub {
        return @_, 2;
       }, 1);

       # Immediately return (1, 2, 3) from the sub, bypassing the eval.
       $sub->unwind(@values, 3);
      }
     }->();
    }

=head1 DESCRIPTION

This class provides an object-oriented interface to L<Scope::Upper>'s functionalities.
A L<Scope::Context> object represents a currently active dynamic scope (or context), and encapsulates the corresponding L<Scope::Upper>-compatible context identifier.
All of L<Scope::Upper>'s functions are then made available as methods.
This gives you a prettier and safer interface when you are not reaching for extreme performance, but rest assured that the overhead of this module is minimal anyway.

The L<Scope::Context> methods actually do more than their subroutine counterparts from L<Scope::Upper> : before each call, the target context will be checked to ensure it is still active (which means that it is still present in the current call stack), and an exception will be thrown if you attempt to act on a context that has already expired.
This means that :

    my $sc;
    {
     $sc = Scope::Context->new;
    }
    $sc->reap(sub { print "hello\n });

will croak when L</reap> is called.

=head1 METHODS

=head2 C<new [ $context ]>

Creates a new immutable L<Scope::Context> object from the L<Scope::Upper>-comptabile context C<$context>.
If omitted, C<$context> defaults to the current context.

=cut

sub new {
 my ($self, $cxt) = @_;

 my $class = Scalar::Util::blessed($self);
 unless (defined $class) {
  $class = defined $self ? $self : __PACKAGE__;
 }

 $cxt = Scope::Upper::UP() unless defined $cxt;

 bless {
  cxt => $cxt,
  uid => Scope::Upper::uid($cxt),
 }, $class;
}

=head2 C<here>

A synonym for L</new>.

=cut

BEGIN {
 *here = \&new;
}

sub _croak {
 shift;
 require Carp;
 Carp::croak(@_);
}

=head2 C<cxt>

Read-only accessor to the L<Scope::Upper> context corresponding to the topic L<Scope::Context> object.

=head2 C<uid>

Read-only accessor to the L<Scope::Upper> UID of the topic L<Scope::Context> object.

=cut

BEGIN {
 local $@;
 eval "sub $_ { \$_[0]->{$_} }; 1" or die $@ for qw<cxt uid>;
}

=pod

This class also overloads the C<==> operator, which will return true if and only if its two operands are L<Scope::Context> objects that have the same UID.

=cut

use overload (
 '==' => sub {
  my ($left, $right) = @_;

  unless (Scalar::Util::blessed($right) and $right->isa(__PACKAGE__)) {
   $left->_croak('Cannot compare a Scope::Context object with something else');
  }

  $left->uid eq $right->uid;
 },
 fallback => 1,
);

=head2 C<is_valid>

Returns true if and only if the topic context is still valid (that is, it designates a scope that is higher than the topic context in the call stack).

=cut

sub is_valid { Scope::Upper::validate_uid($_[0]->uid) }

=head2 C<assert_valid>

Throws an exception if the topic context has expired and is no longer valid.
Returns true otherwise.

=cut

sub assert_valid {
 my $self = shift;

 $self->_croak('Context has expired') unless $self->is_valid;

 1;
}

=head2 C<want>

Returns the Perl context (in the sense of C<wantarray> : C<undef> for void context, C<''> for scalar context, and true for list context) in which is executed the scope corresponding to the topic L<Scope::Context> object.

=cut

sub want {
 my $self = shift;

 $self->assert_valid;

 Scope::Upper::want_at($self->cxt);
}

=head2 C<up [ $frames ]>

Returns a new L<Scope::Context> object pointing to the C<$frames>-th upper scope above the topic context.

This method can also be invoked as a class method, in which case it is equivalent to calling L</up> on a L<Scope::Context> object for the current context.

If omitted, C<$frames> defaults to C<1>.

    sub {
     {
      {
       my $up = Scope::Context->new->up(2); # = Scope::Context->up(2)
       # $up points two contextes above this one, which is the sub.
      }
     }
    }

=cut

sub up {
 my ($self, $frames) = @_;

 if (Scalar::Util::blessed($self)) {
  $self->assert_valid;
 } else {
  $self = $self->new(Scope::Upper::UP(Scope::Upper::SUB()));
 }

 $frames = 1 unless defined $frames;

 my $cxt = $self->cxt;
 $cxt = Scope::Upper::UP($cxt) for 1 .. $frames;

 $self->new($cxt);
}

=head2 C<sub [ $frames ]>

Returns a new L<Scope::Context> object pointing to the C<$frames>-th subroutine scope above the topic context.

This method can also be invoked as a class method, in which case it is equivalent to calling L</sub> on a L<Scope::Context> object for the current context.

If omitted, C<$frames> defaults to C<0>, which results in the closest sub enclosing the topic context.

    outer();

    sub outer {
     inner();
    }

    sub inner {
     my $sub = Scope::Context->new->sub(1); # = Scope::Context->sub
     # $sub points to the context for the outer() sub.
    }

=cut

sub sub {
 my ($self, $frames) = @_;

 if (Scalar::Util::blessed($self)) {
  $self->assert_valid;
 } else {
  $self = $self->new(Scope::Upper::UP(Scope::Upper::SUB()));
 }

 $frames = 0 unless defined $frames;

 my $cxt = Scope::Upper::SUB($self->cxt);
 $cxt = Scope::Upper::SUB(Scope::Upper::UP($cxt)) for 1 .. $frames;

 $self->new($cxt);
}

=head2 C<eval [ $frames ]>

Returns a new L<Scope::Context> object pointing to the C<$frames>-th C<eval> scope above the topic context.

This method can also be invoked as a class method, in which case it is equivalent to calling L</eval> on a L<Scope::Context> object for the current context.

If omitted, C<$frames> defaults to C<0>, which results in the closest eval enclosing the topic context.

    eval {
     sub {
      my $eval = Scope::Context->new->eval; # = Scope::Context->eval
      # $eval points to the eval context.
     }->()
    }

=cut

sub eval {
 my ($self, $frames) = @_;

 if (Scalar::Util::blessed($self)) {
  $self->assert_valid;
 } else {
  $self = $self->new(Scope::Upper::UP(Scope::Upper::SUB()));
 }

 $frames = 0 unless defined $frames;

 my $cxt = Scope::Upper::EVAL($self->cxt);
 $cxt = Scope::Upper::EVAL(Scope::Upper::UP($cxt)) for 1 .. $frames;

 $self->new($cxt);
}

=head2 C<reap $code>

Execute C<$code> when the topic context ends.

See L<Scope::Upper/reap> for details.

=cut

sub reap {
 my ($self, $code) = @_;

 $self->assert_valid;

 &Scope::Upper::reap($code, $self->cxt);
}

=head2 C<localize $what, $value>

Localize the variable described by C<$what> to the value C<$value> when the control flow returns to the scope pointed by the topic context.

See L<Scope::Upper/localize> for details.

=cut

sub localize {
 my ($self, $what, $value) = @_;

 $self->assert_valid;

 Scope::Upper::localize($what, $value, $self->cxt);
}

=head2 C<localize_elem $what, $key, $value>

Localize the element C<$key> of the variable C<$what> to the value C<$value> when the control flow returns to the scope pointed by the topic context.

See L<Scope::Upper/localize_elem> for details.

=cut

sub localize_elem {
 my ($self, $what, $key, $value) = @_;

 $self->assert_valid;

 Scope::Upper::localize_elem($what, $key, $value, $self->cxt);
}

=head2 C<localize_delete $what, $key>

Delete the element C<$key> from the variable C<$what> when the control flow returns to the scope pointed by the topic context.

See L<Scope::Upper/localize_delete> for details.

=cut

sub localize_delete {
 my ($self, $what, $key) = @_;

 $self->assert_valid;

 Scope::Upper::localize_delete($what, $key, $self->cxt);
}

=head2 C<unwind @values>

Immediately returns the scalars listed in C<@values> from the closest subroutine enclosing the topic context.

See L<Scope::Upper/unwind> for details.

=cut

sub unwind {
 my $self = shift;

 $self->assert_valid;

 Scope::Upper::unwind(@_ => $self->cxt);
}

=head2 C<uplevel $code, @args>

Executes the code reference C<$code> with arguments C<@args> in the same setting as the closest subroutine enclosing the topic context, then returns to the current scope the values returned by C<$code>.

See L<Scope::Upper/uplevel> for details.

=cut

sub uplevel {
 my $self = shift;
 my $code = shift;

 $self->assert_valid;

 &Scope::Upper::uplevel($code => @_ => $self->cxt);
}

=head1 DEPENDENCIES

L<Carp> (core module since perl 5), L<Scalar::Util> (since 5.7.3).

L<Scope::Upper> 0.18.

=head1 SEE ALSO

L<Scope::Upper>.

L<Continuation::Escape>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-scope-context at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Scope-Context>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Scope::Context

=head1 COPYRIGHT & LICENSE

Copyright 2011 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Scope::Context

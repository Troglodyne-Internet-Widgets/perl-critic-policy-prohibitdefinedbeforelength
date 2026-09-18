package Perl::Critic::Policy::ValuesAndExpressions::ProhibitDefinedBeforeLength;

# ABSTRACT: length alone asks whether a value is empty; defined first is a second op.

use strict;
use warnings FATAL => 'all';

use 5.014;

use re '/aa';

use Readonly;

use Perl::Critic::Utils qw{ :severities is_hash_key is_method_call };
use parent              qw{Perl::Critic::Policy};

=head1 Perl::Critic::Policy::ValuesAndExpressions::ProhibitDefinedBeforeLength

Asking whether a value is defined and then whether it has a length is two
operations where one does the job:

    return unless defined $uri && length $uri;      # reported
    return unless length $uri;                      # what it means

Since perl 5.12, C<length(undef)> is undef and does not warn, so C<length> alone
is false for undef and for the empty string, and true for everything else --
including C<"0">.

Which of the two to keep depends on what the value is for:

=over 4

=item *

If the length matters -- C<"0"> is a value, and only undef and the empty string
are not -- keep C<length> and drop C<defined>.

=item *

If only truth matters, drop both: C<&& $value> is false for undef, the empty
string and C<"0">.

=back

The policy cannot tell those apart, so it reports the pair and leaves the choice
to whoever reads the finding.  It is worth making in a loop, where the redundant
op runs once per element:

    grep { defined $_ && length $_ } @list;         # reported
    grep { length } @list;                          # length defaults to $_

=head2 PROHIBITED

    defined $x && length $x
    defined($x) and length($x)
    defined $h->{key} && length $h->{key}
    defined && length                               # both of $_

    !defined $x || !length $x                       # the negation
    not defined $x or not length $x

=head2 ALLOWED

    length $x
    defined $x && length $y                         # two different values
    defined $x && length $x > 3                     # length(undef) > 3 warns
    defined $x && $x ne q{}

C<length> followed by a comparison or arithmetic is left alone, because there
the C<defined> is doing a job: C<length(undef) E<gt> 3> is a comparison of undef
and warns.  C<defined $x && $x ne q{}> is a different way to write the same
test and is not reported either.

=head1 CONFIGURATION

None.

=cut

=head2 METHODS

What L<Perl::Critic::Policy> asks of a policy, answered here rather than called
from anywhere.

=head3 supported_parameters

None.

=cut

Readonly::Scalar my $DESC => 'defined before length on the same value';
Readonly::Scalar my $EXPL => 'length(undef) is undef and does not warn: use length alone, or the value alone where only truth matters';

# The operators that join the two halves, positive and negated.
Readonly::Hash my %AND => map { $_ => 1 } qw{&& and};
Readonly::Hash my %OR  => map { $_ => 1 } qw{|| or};
Readonly::Hash my %NOT => map { $_ => 1 } ( q{!}, 'not' );

# What may follow the length for its value to be tested for truth and nothing
# else.  Anything else -- a comparison, arithmetic -- uses the number, and
# length(undef) there warns.
Readonly::Hash my %BOOLEAN_BOUNDARY => map { $_ => 1 } ( qw{&& || // and or xor ? :}, q{,}, q{=>} );

sub supported_parameters { return () }
sub default_severity     { return $SEVERITY_LOW }
sub default_themes       { return qw{troglodyne performance maintenance} }
sub applies_to           { return 'PPI::Token::Word' }

sub violates {
    my ( $self, $elem, undef ) = @_;

    return () unless $elem->content eq 'defined';
    return () if is_hash_key($elem) || is_method_call($elem);

    my $negated = _is_not( $elem->sprevious_sibling );

    my ( $operand, $after ) = _operand($elem);
    return () unless $after && $after->isa('PPI::Token::Operator');
    return () unless $negated ? $OR{ $after->content } : $AND{ $after->content };

    my $length = $after->snext_sibling;
    if ($negated) {
        return () unless _is_not($length);
        $length = $length->snext_sibling;
    }
    return () unless $length && $length->isa('PPI::Token::Word') && $length->content eq 'length';

    my ( $measured, $end ) = _operand($length);
    return () unless $measured eq $operand;
    return () if $end && !_ends_boolean($end);

    return $self->violation( $DESC, $EXPL, $elem );
}

# The operand of a named unary op, as text with the whitespace taken out, and
# the first sibling after it.  defined($x) is the list's contents; defined $x
# runs until an operator other than -> or anything that cannot be part of a
# term.  No operand at all is $_, as perl reads it.
sub _operand {
    my ($op) = @_;

    my $next = $op->snext_sibling;

    if ( $next && $next->isa('PPI::Structure::List') ) {
        my $inside = join( q{}, map { $_->content } $next->schildren );
        return ( _squash( length $inside ? $inside : '$_' ), $next->snext_sibling );
    }

    my @term;
    while ( $next && _continues_term( $next, \@term ) ) {
        push( @term, $next );
        $next = $next->snext_sibling;
    }

    my $text = join( q{}, map { $_->content } @term );
    return ( _squash( length $text ? $text : '$_' ), $next );
}

# A term is a variable, then any run of subscripts, derefs, and method calls
# with their arguments.  A word is part of it only as a method name.
sub _continues_term {
    my ( $elem, $term ) = @_;

    my $last = $term->[-1];
    return $elem->isa('PPI::Token::Symbol') || $elem->isa('PPI::Token::Magic') || $elem->isa('PPI::Token::Cast')
      unless $last;

    return 1 if $elem->isa('PPI::Structure::Subscript');
    return 1 if $elem->isa('PPI::Token::Operator') && $elem->content eq '->';
    return 1 if $last->isa('PPI::Token::Cast')     && ( $elem->isa('PPI::Token::Symbol') || $elem->isa('PPI::Structure::Block') );

    my $after_arrow = $last->isa('PPI::Token::Operator') && $last->content eq '->';
    return 1 if $after_arrow                   && ( $elem->isa('PPI::Token::Word') || $elem->isa('PPI::Structure::List') );
    return 1 if $last->isa('PPI::Token::Word') && $elem->isa('PPI::Structure::List');

    return 0;
}

sub _ends_boolean {
    my ($elem) = @_;

    return 1 if $elem->isa('PPI::Token::Structure') && $elem->content eq q{;};
    return 1 if $elem->isa('PPI::Token::Operator')  && $BOOLEAN_BOUNDARY{ $elem->content };
    return 1 if $elem->isa('PPI::Token::Word')      && $elem->content =~ m/\A(?:if|unless|while|until|for|foreach)\z/;
    return 0;
}

sub _is_not {
    my ($elem) = @_;
    return $elem && $elem->isa('PPI::Token::Operator') && $NOT{ $elem->content };
}

sub _squash {
    my ($text) = @_;
    $text =~ s/\s+//g;
    return $text;
}

1;

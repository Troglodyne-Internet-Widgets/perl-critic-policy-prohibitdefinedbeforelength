use strict;
use warnings FATAL => 'all';

use re '/aa';

use 5.014;

=head1 NAME

t/main.t - which defined-then-length pairs the policy reports, and which it leaves alone

=head1 DESCRIPTION

A table of snippets that must be reported and a table that must not.

The cases that matter are the ones where the defined is doing a job: a length
that is compared or used as a number, where length(undef) warns, and a defined
and a length of two different values.

=cut

use Test::More;
use Test::Warnings qw{warnings};

use Perl::Critic;

# Loaded so that a syntax error in it is a compile failure here rather than
# Perl::Critic reporting no such policy.  Named as a string below, which is
# what ProhibitUnusedImports cannot see.
use Perl::Critic::Policy::ValuesAndExpressions::ProhibitDefinedBeforeLength;    ## no critic (ProhibitUnusedImports)

# -profile => q{} because Perl::Critic otherwise walks up from cwd looking for a
# .perlcriticrc, finds this dist's own, and runs every policy in it against
# these snippets.  The anchored long name because -single-policy is a pattern.
my $POLICY = '^Perl::Critic::Policy::ValuesAndExpressions::ProhibitDefinedBeforeLength$';

my $critic = Perl::Critic->new( -profile => q{}, '-single-policy' => $POLICY, -severity => 1 );

sub check_table {
    my ( $label, %cases ) = @_;
    foreach my $case ( sort keys %cases ) {
        my ( $expected, $source ) = @{ $cases{$case} };
        is( scalar $critic->critique( \$source ), $expected, "$label: $case" ) or diag $source;
    }
    return;
}

check_table(
    'reported',
    'scalar'                => [ 1, q{return unless defined $x && length $x;} ],
    'with parens'           => [ 1, q{die unless defined($x) and length($x);} ],
    'parens on one side'    => [ 1, q{f() if defined $x && length($x);} ],
    'hash element'          => [ 1, q{f() if defined $h->{k} && length $h->{k};} ],
    'bare hash element'     => [ 1, q{f() if defined $h{k} && length $h{k};} ],
    'nested subscripts'     => [ 1, q{f() if defined $h->{a}[0] && length $h->{a}[0];} ],
    'method call'           => [ 1, q{f() if defined $o->name && length $o->name;} ],
    'deref'                 => [ 1, q{f() if defined $$r && length $$r;} ],
    'topic in a grep'       => [ 1, q{my @t = grep { defined $_ && length $_ } @x;} ],
    'bare topic'            => [ 1, q{my @t = grep { defined && length } @x;} ],
    'in a condition'        => [ 1, q{if ( defined $x && length $x ) { f() }} ],
    'followed by more'      => [ 1, q{f() if defined $x && length $x && $y;} ],
    'in a ternary'          => [ 1, q{my $v = defined $x && length $x ? 1 : 0;} ],
    'as a statement'        => [ 1, q{my $ok = defined $x && length $x;} ],
    'negated'               => [ 1, q{next if !defined $p || !length $p;} ],
    'negated with not'      => [ 1, q{next if not defined $p or not length $p;} ],
    'spacing does not hide' => [ 1, q{f() if defined $h->{ k } && length $h->{k};} ],
    'two in one statement'  => [ 2, q{f() if defined $x && length $x && defined $y && length $y;} ],
);

check_table(
    'left alone',
    'length alone'          => [ 0, q{return unless length $x;} ],
    'two values'            => [ 0, q{f() if defined $x && length $y;} ],
    'different elements'    => [ 0, q{f() if defined $h->{a} && length $h->{b};} ],
    'length compared'       => [ 0, q{f() if defined $x && length $x > 3;} ],
    'length in arithmetic'  => [ 0, q{my $n = defined $x && length $x + 1;} ],
    'not equal empty'       => [ 0, q{f() if defined $x && $x ne q{};} ],
    'or, not negated'       => [ 0, q{f() if defined $x || length $x;} ],
    'half negated'          => [ 0, q{f() if !defined $x && length $x;} ],
    'something between'     => [ 0, q{f() if defined $x && $y && length $x;} ],
    'a method named define' => [ 0, q{f() if $o->defined && length $x;} ],
    'a hash key'            => [ 0, q{my %h = ( defined => 1 ); f() if length $x;} ],
    'defined of a call'     => [ 0, q{f() if defined g($x) && length g($x);} ],
);

is( scalar( () = warnings { Perl::Critic->new( -profile => q{}, '-single-policy' => $POLICY ) } ), 0, 'nothing warns on construction' );

done_testing();

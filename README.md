# NAME

Perl::Critic::Policy::ValuesAndExpressions::ProhibitDefinedBeforeLength - length alone asks whether a value is empty; defined first is a second op.

# VERSION

version 0.001

# Perl::Critic::Policy::ValuesAndExpressions::ProhibitDefinedBeforeLength

Asking whether a value is defined and then whether it has a length is two
operations where one does the job, and in a boolean context neither is needed:

```
return unless defined $uri && length $uri;      # what you see - violates
return unless length $uri;                      # what it means - still violates
return unless $uri;                             # what should actually be done
```

When the length itself matters, shape the value before the comparison rather
than guarding the comparison:

```
return if defined $uri && length $uri > 2048;   # we care about the length - violates
$uri //= q{};                                   # shape the data first
return if length $uri > 2048;                   # correct solution
```

Under `use warnings FATAL => 'all'`, `length(undef) > 2048` dies.
That is working as designed: it forces the value into shape before it reaches
the conditional, instead of a `defined` in front of every use.

In a boolean context, the value alone is false for undef, the empty string and
`"0"`.  `length` is true for `"0"`, and that difference is the reason the
pattern spread.  It catches as many bugs as it causes -- a string that was never
passed through `int()`, for one -- so the policy asks for the cheaper test and
accepts the wart.  Where `"0"` is a real value, say so with a `## no critic`
and a reason.

The saving is largest in a loop, where the redundant ops run per element:

```perl
grep { defined $_ && length $_ } @list;         # 3 calls
grep { length } @list;                          # one call
grep { $_ } @list;                              # no calls!
```

## PROHIBITED

Anywhere:

```perl
defined $x && length $x
defined($x) and length($x)
defined $h->{key} && length $h->{key}
defined && length                               # both of $_
defined $x && length $x > 3                     # shape $x first

!defined $x || !length $x                       # the negation
not defined $x or not length $x
```

In a boolean context -- the condition of `if`, `unless`, `while` or
`until`, a statement modifier, the operand of `!` or `not`, the condition of
`?:`, or the block of `grep`, `first`, `any`, `all`, `none` or `notall`:

```
length $x                                       # waste of time in boolean context
!length $x
```

## ALLOWED

```perl
$x                                              # in a boolean context
defined $x && length $y                         # two different values
defined $x && $x ne q{}
length $x > 3                                   # the length is used
my $size = length $x;                           # not a boolean context
```

`defined $x && $x ne q{}` is a different way to write the test, and is not
reported.

## CAVEATS

Assigning the result of `length` and using it later will not be checked.

A `length` that is the operand of `&&` or `||` in an assignment or a
`return`, such as `return length $x && $y`, is a value rather than a
condition, and is not reported either.

# CONFIGURATION

None.

## METHODS

What [Perl::Critic::Policy](https://metacpan.org/pod/Perl%3A%3ACritic%3A%3APolicy) asks of a policy, answered here rather than called
from anywhere.

### supported\_parameters

None.

# AUTHORS

Current Maintainers:

- George S. Baugh <george@troglodyne.net>

# COPYRIGHT AND LICENSE

Copyright (c) 2026 Troglodyne LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

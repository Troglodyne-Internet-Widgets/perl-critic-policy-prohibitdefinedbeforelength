# NAME

Perl::Critic::Policy::ValuesAndExpressions::ProhibitDefinedBeforeLength - length alone asks whether a value is empty; defined first is a second op.

# VERSION

version 0.001

# Perl::Critic::Policy::ValuesAndExpressions::ProhibitDefinedBeforeLength

Asking whether a value is defined and then whether it has a length is two
operations where one does the job:

```
return unless defined $uri && length $uri;      # reported
return unless length $uri;                      # what it means
```

Since perl 5.12, `length(undef)` is undef and does not warn, so `length` alone
is false for undef and for the empty string, and true for everything else --
including `"0"`.

Which of the two to keep depends on what the value is for:

- If the length matters -- `"0"` is a value, and only undef and the empty string
are not -- keep `length` and drop `defined`.
- If only truth matters, drop both: `&& $value` is false for undef, the empty
string and `"0"`.

The policy cannot tell those apart, so it reports the pair and leaves the choice
to whoever reads the finding.  It is worth making in a loop, where the redundant
op runs once per element:

```perl
grep { defined $_ && length $_ } @list;         # reported
grep { length } @list;                          # length defaults to $_
```

## PROHIBITED

```perl
defined $x && length $x
defined($x) and length($x)
defined $h->{key} && length $h->{key}
defined && length                               # both of $_

!defined $x || !length $x                       # the negation
not defined $x or not length $x
```

## ALLOWED

```
length $x
defined $x && length $y                         # two different values
defined $x && length $x > 3                     # length(undef) > 3 warns
defined $x && $x ne q{}
```

`length` followed by a comparison or arithmetic is left alone, because there
the `defined` is doing a job: `length(undef) > 3` is a comparison of undef
and warns.  `defined $x && $x ne q{}` is a different way to write the same
test and is not reported either.

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

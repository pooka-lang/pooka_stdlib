# List primitives

From this directory, run `pooka run`. The package uses the local standard library.
Each operation gets one warm-up and five timed samples. Input construction and
result checks sit outside the timer. Times are integer milliseconds; GC and
clock resolution make small samples noisy.

The reversal and length inputs contain one million integers. Prepend builds a
million-element list. Sorting uses 50,000 integers permuted by multiplication
modulo 50,000, rather than an already sorted or reversed input.

| Operation | Before, median ms | After, median ms |
| --- | ---: | ---: |
| reverse | 15 | 3 |
| length | 8 | 1 |
| prepend one million times | 9 | 11 |
| sort | 29 | 2 |
| sort_by | 27 | 27 |

These are local samples, not promised speed ratios. Direct OTP controls measured
1 ms for length, 3 ms for reversal and 2 ms for sorting in the second run.
Prepend keeps its existing single cons bridge; its small difference is noise,
not an improvement. Custom sorting keeps its Pooka comparison algorithm and
stable ordering. Its merge now attaches the remaining run with `lists:reverse/2`,
which avoids reversing and copying the accumulated prefix again.

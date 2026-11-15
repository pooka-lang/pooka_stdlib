# Changelog

All notable changes to the Pooka standard library are documented in this file.

## 0.3.1

### Documentation

- Add 47 checked examples for string and byte trees, Dynamic readers, composable decoders and URI helpers.
- Point repository metadata and test badges to `pooka-lang/stdlib`.

## 0.3.0

### Added

- Result collection, flattening, recovery and ordered partitioning; matching Option collection, flattening and lazy alternatives.
- List prefix operations, fixed-size and key-based chunking, grouping, early-stopping folds and reduction; dictionary conflict resolution, selection, dropping and iteration.
- Code-point padding and prefix/suffix removal, explicit UTF-8 byte counts and grapheme-aware splitting, counting, slicing and reversal.
- Immutable `StringTree` and `BytesTree` builders with constant-time appends and iterative rendering. Byte trees also preserve non-byte-aligned bitstrings.
- Checked `Dynamic` capabilities and composable decoders with nested field/index error paths, optional fields, alternatives and record-building helpers.
- Typed URI parsing and recomposition, strict percent encoding/decoding and ordered form query helpers through OTP.

- Compare strings in Unicode code point order with `string.compare`, including stable sorting by string fields (#5).

### Removed

- Remove the benchmark project and keep application examples outside the library repository.

## 0.2.0

### Performance

- Use OTP fast paths for list length, reversal, concatenation and default sorting; join custom-sort runs without rebuilding their accumulated prefix twice (#1).

### Added

- List traversal, splitting, indexed callbacks, pair lookup and short-circuiting Result helpers (#2).
- `Dict.get_or` and `Dict.upsert`, string splitting and codepoint dropping, and exact integer comparison.
- Boundary examples and Pooka tests for empty inputs, callback order, Unicode and early returns.

## 0.1.0

- Initial release of `pooka_stdlib`.
- Licensed under the Apache License, Version 2.0.

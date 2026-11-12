# Changelog

All notable changes to the Pooka standard library are documented in this file.

## Unreleased

### Performance

- Use OTP fast paths for list length, reversal, concatenation and default sorting; join custom-sort runs without rebuilding their accumulated prefix twice (#1).

### Added

- List traversal, splitting, indexed callbacks, pair lookup and short-circuiting Result helpers (#2).
- `Dict.get_or` and `Dict.upsert`, string splitting and codepoint dropping, and exact integer comparison.
- Boundary examples and Pooka tests for empty inputs, callback order, Unicode and early returns.

## 0.1.0

- Initial release of `pooka_stdlib`.
- Licensed under the Apache License, Version 2.0.

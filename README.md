<p align="center">
  <img src="assets/noxy.png" alt="Pooka mascot" width="280" />
</p>

# Pooka Standard Library

[![Package Version](https://img.shields.io/hexpm/v/pooka_stdlib?style=for-the-badge&color=75618E)](https://hex.pm/packages/pooka_stdlib)
[![Hex Docs](https://img.shields.io/website?url=https%3A%2F%2Fpooka-stdlib.hexdocs.pm%2F&style=for-the-badge&label=hex&up_message=docs&up_color=FF891F&down_message=not%20found&down_color=lightgrey)](https://pooka-stdlib.hexdocs.pm/)
[![Tests](https://img.shields.io/github/actions/workflow/status/pooka-lang/pooka_stdlib/test.yml?style=for-the-badge&label=tests)](https://github.com/pooka-lang/pooka_stdlib/actions/workflows/test.yml)

The standard library for [Pooka](https://github.com/pooka-lang/pooka), for use with Pooka 0.1.0 and Erlang/OTP 29.

See the [documentation](https://pooka-stdlib.hexdocs.pm/) for the API and examples. Compiler installation and language information are in the [Pooka repository](https://github.com/pooka-lang/pooka).

## Usage

Add the library to your Pooka project:

```sh
pooka add pooka_stdlib
```

Or declare it in `pooka.toml`:

```toml
[dependencies]
pooka_stdlib = ">= 0.1.0 and <= 1.0.0"
```

> Standard Library comes as a dependency in all new Pooka projects.

```pooka
module main

import pooka/list

main() {
  assert list.map([1, 2, 3], fn(n) { n * 2 }) == [2, 4, 6]
}
```

## Licence

Licensed under the [Apache License, Version 2.0](LICENSE).

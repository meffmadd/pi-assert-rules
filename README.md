# pi-assert-rules

Community rule library for [pi-assert](https://github.com/meffmadd/pi-assert).
Install rules via `/asserts install` in pi.

## Structure

```
rules/
  defaults.json    ← seed rules, one file with multiple asserts
```

Each `.json` file in `rules/` is a standard `asserts.json` object with an
extra `description` field per assert (used by the install UI, stripped on
install).

## Usage

In pi, run `/asserts install` to browse and install rules from this repo.

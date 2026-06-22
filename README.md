# pi-assert-rules

Community rule library for [pi-assert](https://github.com/meffmadd/pi-assert).
Install rules via `/asserts install` in pi.

## Structure

Each `.json` file in `rules/` is a standard `asserts.json` object with
an extra `description` field per assert (used by the install UI, stripped
on install). Subdirectories are supported, arbitrarily deep:

```
rules/
  general.json
  security/
    writes.json
    reads.json
  git/no-force-push.json
```

The install picker lists files flat, sorted by path, with directories
shown in the label (`security/writes`). Nesting is purely organisational —
each assert installs into the flat `owner/repo` section of the user's
`.pi/asserts.json` keyed by its `name`.

Assert names must be unique within a file and should be unique across
the repo (collisions overwrite; the installer warns).

## Usage

In pi, run `/asserts install` to browse and install rules from this repo.

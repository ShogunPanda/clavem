### 2.2.1 / 2016-03-30

* Remove invalid path manipulation in the binary.

### 2.2.0 / 2016-03-30

* `Clavem::Authorizer#i18n` now returns a `Bovem::I18n` object.
* Changed signatures of `Clavem::Authorizer.instance` and `Clavem::Authorizer#initialize`.
* Updated dependencies and linted code.
* Dropped support for Ruby < 2.3.

### 2.1.0 / 2014-04-06

* Removed eventmachine as dependency so that is usable even on JRuby.
* Added `skip-callback` command line option.
This directory contains various helper shell script fragments, to share code between the various
scripts in this repository.

Naming convention
-----------------

1. "is_" / "does_" methods

All methods starting with "is_" return an exit code, that can be checked.
Typical idioms: ```is_socket_available || _abort_ "No socket available"

2. "get_" methods

All methods starting with "get_" print the resulting string/numeric value
to stdout, from which it can be captured in local variables by the callee,
e.g. ```my_default="$(get_some_default_value)"```

3. "verify_" methods

Ensures a condition is fulfiled -- aborts if not.

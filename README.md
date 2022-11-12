# print\_functions.sh

A simple Bash shell script to print out the function names of a Bash shell script, or to print out the definition of a single function within a Bash script.

## Usage

`./print_functions.sh FILE [FUNCTION]`

When invoked on just a file, print\_functions.sh prints out the name and line number for every function declaration in FILE.

When invoked on a file with a function name, print\_functions.sh prints out the entire function definition. Or it attempts to. This functionality doesn't work very well and I'm always trying to account for different edge cases.

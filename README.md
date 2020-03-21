# run-d

`run-d` is a Bash program which takes in a command string and
a list of files.
The command is initially executed and when a change to any of
the files in the given list is recorded, the previous running
version of the command (if any) will be killed and re-run.  

To install the program, `source` the file `run-d.sh` in this
project's root in the `.zshrc` or `.bashrc`. This will ensure
that all shells know the `run-d` command.

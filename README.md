
# A simple bash script to make your life easier when building cpp applications

## Features

* Makefile generation
* Build automation
* Shortcuts for macro definitions

## Notice:

* The configuration file must be located in the current working directory
* For the makefile generation to work properly, the extension of every header file must be either .h or .hpp
* For the macro shortcut system to work properly, the macros must be of the format "__.*__", for example "__VERBOSE__"
* When listing executables with the "--executable" flag the directory and the extension
of the executable need not be specified

## Installation:

```bash
wget https://raw.githubusercontent.com/billsioros/cpp-build/master/cpp-build.sh;
sudo mv -i cpp-builder /usr/local/bin/cpp-build;
```

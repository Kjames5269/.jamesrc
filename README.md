# .jamesrc
Shell profile

This is a set of shell files that can make your terminal experience better

#To use:
source the absolute path to .jamesrc/main.sh to your shell profile or rc file
`source /Users/kjames5269/.jamesrc/main.sh`

Main will source all scripts in the .jamesrc file that are prepended with underscores.

There are a few useful functions and aliases that are created by default.

sdir and ldir to save and load directories
if you have a workspace that is registered by calling createFiles then
iproject will take you to the project directory in your workspace.

build is a nice command if you are working with maven or Codice repos
build --help

Other than that `printenv` and `alias` to see whats added if you dont want to poke around in the files.
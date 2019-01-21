#!/bin/sh
function echoerr() {
    printf "[\033[0;31mERROR\033[0m] " >&2
    echo $@ >&2
    return 1
}

function echoinf() {
    printf "[\033[38;5;20mINFO\033[0m] " >&2
    echo $@ >&2
}

function echodebug() {
    printf "[\033[38;5;227mDEBUG\033[0m] " >&2
    echo $@ >&2
}

function echotrace() {
    printf "[\033[38;5;244mTRACE\033[0m] " >&2
    echo $@ >&2
}
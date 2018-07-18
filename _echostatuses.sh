#!/usr/bin/env bash
echoerr() { printf "[\033[0;31mERROR\033[0m] %s\n" "$*" >&2; }
echoinf() { printf "[\033[38;5;20mINFO\033[0m] %s\n" "$*" >&2; }

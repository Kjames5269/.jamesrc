#!/usr/bin/env bash
alias sdir="pwd > ~/.savedDirectory"

ldir () {
	if [[ $1 == "-w" ]]; then
		cat ~/.savedDirectory
		return 0
	fi
	cd $(cat ~/.savedDirectory)
}

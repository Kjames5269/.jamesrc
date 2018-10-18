#!/bin/sh
alias sdir="pwd > ${JRC_META_PATH}meta-savedDir"

ldir () {
	if [[ $1 == "-w" ]]; then
		cat ${JRC_META_PATH}meta-savedDir
		return 0
	fi
	cd $(cat ${JRC_META_PATH}meta-savedDir)
}

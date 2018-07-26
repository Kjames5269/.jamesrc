#!/bin/zsh

alias cb="hub rev-parse --abbrev-ref HEAD"

# A git wrapper just so you can pass cb as current branch to any command
# To get the auto completion scripts shamelessly steal them from the hub github using... TODO

gitWrap() {

	if [[ ${@: -1} == "cb" ]]; then
		length=$(($# - 1))

		currBranch=$(cb)
		
		if [ $? -ne 0 ]; then
			return 1
		fi

		ARGS=(${@:1:$length} $currBranch)

	else
		ARGS=(${@})
	fi

	hub ${ARGS[@]}

}

alias git=gitWrap

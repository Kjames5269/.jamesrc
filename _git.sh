#!/bin/zsh

alias cb="hub rev-parse --abbrev-ref HEAD"
alias cc="git rev-parse HEAD"

COMMIT_PREPEND_TAG="-ma"

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

    elif [[ $1 == "commit" ]] && [[ $2 == "$COMMIT_PREPEND_TAG" ]]; then
        length=$(($# - 1))

        currBranch=$(cb | cut -f1,2 -d '-' )

        msg=$(echo ${3})

        if [ $? -ne 0 ]; then
            return 1
        fi

        firstWord=$(echo ${msg} | cut -f1 -d ' ')

        if [[ "$firstWord" != "$currBranch" ]]; then
            ARGS=("${1}" "-m" "\"${currBranch} ${msg}\"")
        else
            RGS=(${@})
        fi

	else
		ARGS=(${@})
	fi

	hub ${ARGS[@]}

}

alias git=gitWrap
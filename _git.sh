#!/bin/zsh

alias cb="hub rev-parse --abbrev-ref HEAD"
alias cc="git rev-parse HEAD"

TIMELY_FETCH=5
# in minutes

COMMIT_PREPEND_TAG="-:"

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

        # git (1)commit -: commit message starts at 3
        msg=$(echo ${@:3:$#})

        if [ $? -ne 0 ]; then
            return 1
        fi

        firstWord=$(echo ${msg} | cut -f1 -d ' ')

        if [[ "$firstWord" != "$currBranch" ]]; then
            ARGS=("${1}" "-m" "${currBranch} ${msg}")
        else
            ARGS=("${1}" "-m" "\"${msg}\"")
        fi

    elif [[ $1 == "fetch" ]]; then
        updateFetchDate
        ARGS=(${@})

	else
		ARGS=(${@})
	fi

	hub ${ARGS[@]}

}

alias git=gitWrap

updateFetchDate() {
        echo $(date +'%Y%m%d%H%M') > '.git/CD_LAST_FETCH'
}

autoFetch() {
    if [ -d .git ]; then
        if [ -f '.git/CD_LAST_FETCH' ]; then
            lastFetch=$(cat '.git/CD_LAST_FETCH')
            currDate=$(date +'%Y%m%d%H%M')
            if [[ $(($currDate - $lastFetch)) -lt $TIMELY_FETCH ]]; then
                return 0
            fi
        fi
        git fetch --all
        echo $(date +'%Y%m%d%H%M') > '.git/CD_LAST_FETCH'
    fi
}

cdWrap() {
    cd $@
    autoFetch
}

alias cd=cdWrap
#!/bin/zsh

alias cb="/usr/bin/git rev-parse --abbrev-ref HEAD"
alias cc="/usr/bin/git rev-parse HEAD"

TIMELY_FETCH=1
# in minutes

COMMIT_PREPEND_TAG="-:"

# A git wrapper just so you can pass cb as current branch to any command
# To get the auto completion scripts shamelessly steal them from the hub github using... TODO

unalias git
whichGit=$(which git)

function gitWrap() {

    setup() {

        if [ -z ${whichGit} ]; then
            whichGit=$(which git)
        fi

        GIT_HOME=$(${whichGit} rev-parse --show-toplevel)
    }

	if [[ ${@: -1} == "cb" ]]; then
		length=$(($# - 1))

		currBranch=$(cb)

		ARGS=(${@:1:$length} $currBranch)
    else
        ARGS=($@)
    fi

    if typeset -f pre$1Hook > /dev/null; then

        setup

        pre$1Hook ${ARGS[@]}

        if [ $? -ne 0 ]; then
            return $(( $? == 2 ))
        fi

    fi

    if typeset -f checkFetchGuard > /dev/null; then
        checkFetchGuard
    fi

    which hub > /dev/null
    if [ $? -eq 0 ]; then
	    hub ${ARGS[@]}
	else
		${whichGit} ${ARGS[@]}
	fi

    if typeset -f post$1Hook > /dev/null; then

        post$1Hook ${ARGS[@]}

        if [ $? -ne 0 ]; then
            return $(( $? != 2 ))
        fi

    fi

	# remove all set variables
	unset ARGS
	unset length
    unset GIT_HOME

}

alias git=gitWrap

function getFirstJiraCommit() {
    oldIFS=$IFS
    IFS=$'\n'
    for i in $(${whichGit} log --format="%H %s"); do
        if [ -z $FCommit ]; then

            FCommit=$(echo $i | cut -f2- -d ' ')
            FTag=$(echo $i | cut -f2 -d ' ')
            continue
        fi
        #echo "$i"

        CTag=$(echo $i | cut -f2 -d ' ')

        if [[ ${CTag} != ${FTag} ]]; then

            firstJiraCommit=$(echo $i | cut -f1 -d ' ')
            break
        fi
        FCommit=$(echo $i | cut -f2- -d ' ')

    done
    IFS=$oldIFS
}

function cleanupGetFirstJiraCommit() {
    unset oldIFS
    unset FCommit
    unset FTag
    unset CTag
    unset firstJiraCommit

}



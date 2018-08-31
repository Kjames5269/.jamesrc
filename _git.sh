#!/bin/zsh

alias cb="/usr/bin/git rev-parse --abbrev-ref HEAD"
alias cc="/usr/bin/git rev-parse HEAD"

# A git wrapper just so you can pass cb as current branch to any command
# To get the auto completion scripts shamelessly steal them from the hub github using... TODO

unalias git

function gitWrap() {

    # # # # # # # # # # # # # # # # # # # # #
    # "Private" functions
    #
    function gitWrapSetup() {

        if [ -z ${whichGit} ]; then
            unalias git

            # if hub is installed use hub otherwise use git
            which hub > /dev/null
            if [ $? -eq 0 ]; then
                whichGit=$(which hub)
            else
                whichGit=$(which git)
            fi

            alias git=gitWrap
        fi

        GIT_HOME=$(${whichGit} rev-parse --show-toplevel)
    }

	function gitWrapCleanUp() {
        unset ARGS
        unset length
        unset GIT_HOME
        unset whichGit
    }

    function currBranchCheck() {
        # if the last argument is cb then transform it into the current branch
	    if [[ ${@: -1} == "cb" ]]; then
		length=$(($# - 1))

		currBranch=$(cb)

		ARGS=(${@:1:$length} $currBranch)
        else
            ARGS=($@)
        fi

    }

    # --------------------------------------

    currBranchCheck $@
    gitWrapSetup

    # # # # # # # # # # # # # # # # # # # # #
    # -- PreHooks
    #
    if typeset -f pre$1Hook > /dev/null; then

        pre$1Hook ${ARGS[@]}
        test $? -ne 0 && gitWrapCleanUp && return $(( $? == 2 ))

    fi

    if typeset -f checkFetchGuard > /dev/null; then
        checkFetchGuard
    fi

    # --------------------------------------

	${whichGit} ${ARGS[@]}

    # # # # # # # # # # # # # # # # # # # # #
    # -- PostHooks
    #
    if typeset -f post$1Hook > /dev/null; then

        post$1Hook ${ARGS[@]}
        test $? -ne 0 && gitWrapCleanUp && return $(( $? == 2 ))

    fi

    # --------------------------------------

	# remove all set variables
    gitWrapCleanUp
    unset -f gitWrapCleanUp
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
    unset -f currBranchCheck
    unset -f gitWrapSetup

}



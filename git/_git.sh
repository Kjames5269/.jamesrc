#!/bin/sh

alias cb="/usr/bin/git rev-parse --abbrev-ref HEAD"
alias cc="/usr/bin/git rev-parse HEAD"

# A git wrapper just so you can pass cb as current branch to any command
# To get the auto completion scripts shamelessly steal them from the hub github using... TODO

test $(alias | egrep "^git=") && unalias git

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

    GIT_HOME=$(${whichGit} rev-parse --show-toplevel) &> /dev/null
    GIT_OUTPUT="/dev/stdout"
}

function gitWrap() {

    # # # # # # # # # # # # # # # # # # # # #
    # "Package Private" functions
    #

	function gitWrapCleanUp() {
        unset ARGS length GIT_HOME whichGit debugRetval

        if [ -f ${GIT_OUTPUT} ] && [[ ! ${GIT_OUTPUT} =~ "^/dev/.*$" ]] ; then
            /bin/rm ${GIT_OUTPUT}
        fi

        cleanGitHelpers
        unset GIT_OUTPUT
        unset GIT_DEBUG debugRetval
    }

    # --------------------------------------

    # Give us access to the helper functions
    gitWrapHelperFunctions
    checkDebugMode $1 && shift
    currBranchCheck $@
    gitWrapSetup

    # # # # # # # # # # # # # # # # # # # # #
    # -- PreHooks
    #
    if typeset -f pre$1Hook > /dev/null; then

        C pre$1Hook ${ARGS[@]}
        test $? -ne 0 && gitWrapCleanUp && return $(( $? == 2 ))

    fi

    if typeset -f checkFetchGuard > /dev/null; then
        C checkFetchGuard
    fi

    # --------------------------------------

	C ${whichGit} ${ARGS[@]} &> ${GIT_OUTPUT}

    retval=$?
	if [ ${retval} -ne 0 ]; then
	    if [ -f ${GIT_OUTPUT} ]; then
            /bin/cat ${GIT_OUTPUT} 1>&2
        fi
        gitWrapCleanUp
        unset -f gitWrapCleanUp
        return ${retval}
    fi

    # # # # # # # # # # # # # # # # # # # # #
    # -- PostHooks
    #
    if typeset -f post$1Hook > /dev/null; then

        C post$1Hook ${ARGS[@]}
        test $? -ne 0 && gitWrapCleanUp && return $(( $? == 2 ))

    fi

    # --------------------------------------

	# remove all set variables
    gitWrapCleanUp
    unset -f gitWrapCleanUp
    return ${retval}
}

alias git=gitWrap
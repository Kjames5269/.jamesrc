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

    if [[ $1 == "debug" ]]; then
        GIT_DEBUG=1
        shift
    elif [[ $1 == "trace" ]]; then
        GIT_DEBUG=2
        shift
    else
        GIT_DEBUG=0
    fi
    #saveEnvVars

    # # # # # # # # # # # # # # # # # # # # #
    # "Package Private" functions
    #

	function gitWrapCleanUp() {
        unset ARGS
        unset length
        unset GIT_HOME
        unset whichGit

        unset debugRetval

        if [ -f ${GIT_OUTPUT} ] && [[ ! ${GIT_OUTPUT} =~ "^/dev/.*$" ]] ; then
            /bin/rm ${GIT_OUTPUT}
        fi
        unset GIT_OUTPUT
        unset -f C
        unset GIT_DEBUG
        unset debugRetval
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

    function C() {
        DEBUG trace ${1} "starting... ARGS=(${@:2})"
        ${1} ${@:2}
        DEBUG trace ${1} "finishing... retval=$?..."
    }
    # --------------------------------------

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

function getFirstJiraCommit() {
    oldIFS=$IFS
    IFS=$'\n'
    for i in $(${whichGit} log --format="%H %s"); do

        if [ -z $FCommit ]; then

            FCommit=$(echo $i | cut -f2- -d ' ')
            FTag=$(echo $i | cut -f2 -d ' ')
            DEBUG $0 "The first commit is :: \"$FCommit\" :: With tag ${FTag}"
            continue
        fi

        CTag=$(echo $i | cut -f2 -d ' ')

        DEBUG $0 "log :: $i :: With tag ${CTag}"

        if [[ ${CTag} != ${FTag} ]]; then

            firstJiraCommit=$(echo $i | cut -f1 -d ' ')
            DEBUG $0 "Returning ${FCommit}"
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
}

_GIT_PERSONAL_COMMIT_LOG="personalCommits.log"

function prelogHook() {
    if [[ ${ARGS[2]} == "personal" ]]; then
        if [ -f ${GIT_HOME}/.git/${_GIT_PERSONAL_COMMIT_LOG} ]; then
            cat ${GIT_HOME}/.git/${_GIT_PERSONAL_COMMIT_LOG}
            return 2
        else
            echo "no personal log yet..."
            return 1
        fi
    elif [[ ${ARGS[2]} == "head" ]]; then
        cut -f1,2,3,6- -d ' ' ${GIT_HOME}/.git/logs/HEAD
        return 2
    fi

}
function createLogEntry() {
    echo "$(date +'%m.%d %H:%M') -- ${1} -- $(cb) -- $(${whichGit} log --format="%H -- %s" | head -1) ${2}" >> ${GIT_HOME}/.git/${_GIT_PERSONAL_COMMIT_LOG}
}

#ToDo when the month is > x difference get the first log entry and delete all entries of the same month.
#This can be done because git only saves dangling commits for so long and having a few months of logs should be more than enough time
#To realize that you can fix something

function DEBUG() {
    # Get the return value of whatever came before it so $? can be used after DEBUG statements
    debugRetval=$?
    case $1 in
        "trace")
            debugLevel="trace"
            debugNo=2
            shift
            ;;
        *)
            debugLevel="debug"
            debugNo=1
            ;;
    esac
    debugCaller=$1
    shift
    test ${GIT_DEBUG} -ge ${debugNo} && echo${debugLevel} "${debugCaller}(): ${@}"
    unset debugCaller
    unset debugNo
    unset debugLevel
    return $debugRetval
}
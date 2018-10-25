#!/bin/sh

# List of `package private` functions. Called at the beginning of git_wrap
# and unset at the end of git_wrap
function gitWrapHelperFunctions() {

    function C() {
        DEBUG trace ${1} "starting... ARGS=(${@:2})"
        ${1} ${@:2}
        DEBUG trace ${1} "finishing... retval=$?..."
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

    function checkDebugMode() {
        case $1 in
            "debug")
                GIT_DEBUG=1
                return 0
                ;;
            "trace")
                GIT_DEBUG=2
                return 0
                ;;
            *)
                GIT_DEBUG=0
                return 1
                ;;
        esac
    }

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
        unset oldIFS FCommit FTag CTag firstJiraCommit
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
        unset debugCaller debugNo debugLevel

        return $debugRetval
    }

    function getUserProjTuple() {
        C normalizeURL ${1}

        if C gitIsSSH ${gitNormalizedURL}; then
        # If the remote is ssh it has the following format git@github.com:User/proj.git
            userProjTuple=$(echo ${gitNormalizedURL} | rev | cut -f1 -d ':' | cut -f2- -d '.' | rev)
        else
        # It'll be https://github.com/User/proj
            userProjTuple=$(echo ${gitNormalizedURL} | rev | cut -f1,2 -d '/' | rev)
        fi
        unset gitNormalizedURL
        DEBUG $0 "Returning ${userProjTuple}"
    }

    function normalizeURL() {
        if [[ $1 =~ "^.*/$" ]]; then
            gitNormalizedURL=$(echo ${1} | rev | cut -c2- | rev)
        else
            gitNormalizedURL=${1}
        fi
        DEBUG "trace" $0 "Returning ${gitNormalizedURL}"
    }

    function gitIsSSH() {
        test $# -eq 1 || echoerr "$0 requires 1 argument"

        if [[ ${1} =~ "^.*@.*\.git$" ]]; then
            return 0
        else
            return 1
        fi
    }

    function cleanGitHelpers() {
        # Unsets all functions in this file.
        unset -f $(egrep "function.*\(\) \{$"  ${JRC_BASE_PATH}git/_gitHelpers.sh | egrep -v "^function gitWrapHelperFunctions\(\) \{$" | awk '{print $2}' | cut -f1 -d '(')
    }

}
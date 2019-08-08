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
        length=$(($# - 1))
        currBranch=$(cb) 2> /dev/null

	    if [[ ${@: -1} == "cb" ]]; then
            ARGS=(${@:1:$length} $currBranch)

		elif [[ ${@: -1} =~ "^cb:[a-zA-Z0-9]+$" ]]; then
            local other=$(echo ${@: -1} | cut -f2 -d ':')
            ARGS=(${@:1:$length} "${currBranch}:${other}")

        elif [[ ${@: -1} =~ "^[a-zA-Z0-9]+:cb$" ]]; then
            local other=$(echo ${@: -1} | cut -f1 -d ':')
            ARGS=(${@:1:$length} "${other}:${currBranch}")

        else
            ARGS=($@)
        fi
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

    function getUserProjTuple() {
        C validateGITURL ${1} || return $?
        C normalizeURL ${1}

        if C gitIsSSH ${gitNormalizedURL}; then
        # If the remote is ssh it has the following format git@github.com:User/proj.git
            userProjTuple=$(echo ${gitNormalizedURL} | rev | cut -f1 -d ':' | rev)
        else
        # It'll be https://github.com/User/proj
            userProjTuple=$(echo ${gitNormalizedURL} | rev | cut -f1,2 -d '/' | rev)
        fi
        unset gitNormalizedURL
        DEBUG $0 "Returning ${userProjTuple}"
    }

    function validateGITURL() {
        if [[ $1 =~ "^(https?://.+\.|.+@.+\.).+(/|:).*/.*$" ]]; then
            return 0
        fi
        DEBUG $0 "$1 is an invalid URL!"
        return 1
    }

    function normalizeProj() {
        if [[ $1 =~ "\.git$" ]]; then
            echo ${1} | rev | cut -f2- -d '.' | rev
        else
            echo ${1}
        fi
    }

    function normalizeURL() {
        if [[ $1 =~ "^.*/$" ]]; then
            gitNormalizedURL=$(normalizeProj $(echo ${1} | rev | cut -c2- | rev))
        else
            gitNormalizedURL=$(normalizeProj ${1})
        fi

        DEBUG "trace" $0 "Returning ${gitNormalizedURL}"
    }

    function gitIsSSH() {
        test $# -eq 1 || echoerr "$0 requires 1 argument"

        if [[ ${1} =~ "@" ]]; then
            return 0
        else
            return 1
        fi
    }

    function testVar() {
        if [ -z ${(P)1} ]; then
            echoerr "$1 has not been set."
            return 1
        fi

        return $( test ${(P)1} -eq 1 );
    }

    function cleanGitHelpers() {
        # Unsets all functions in this file.
        unset -f $(egrep "function.*\(\) \{$"  ${JRC_BASE_PATH}git/_gitHelpers.sh | egrep -v "^function gitWrapHelperFunctions\(\) \{$" | awk '{print $2}' | cut -f1 -d '(')
    }

}
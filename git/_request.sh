#!/bin/sh

AUTO_SET_REMOTE=0
ASSUME_ORIGIN=1

function prepushHook() {
    C getGitURL $@

    if ! testVar ASSUME_ORIGIN && [ ${#ARGS[@]} -ne 3 ]; then
        return 0
    fi

    trackedBranch=$(${whichGit} for-each-ref --format='%(upstream:short)' $(${whichGit} symbolic-ref -q HEAD))
    if [ ! -z ${trackedBranch} ]; then
        return 0
    fi

    if ! testVar AUTO_SET_REMOTE; then
        setUpstream=""
    else
        setUpstream="--set-upstream"
    fi

    if [ ${#ARGS[@]} -eq 1 ]; then
        ARGS[2]="origin"
        ARGS[3]=$(cb)
    fi

    ARGS=(${ARGS[1]} ${setUpstream} ${ARGS[@]:1})

    unset trackedBranch
    unset setUpstream

}

function prepubHook() {
    ARGS[1]="push"
    prepushHook ${ARGS[@]}
}

function postpubHook() {
    if [ $? -eq 0 ]; then
        C open ${lGIT_URL}
    fi
}

function prerequestHook() {
    DEBUG $0 "lGIT_URL :: ${lGIT_URL}"
    if [ $# -eq 1 ] && [ ! -z ${lGIT_URL} ]; then
        open ${lGIT_URL}
    else
        unset lGIT_URL
        C getGitURL ${ARGS[@]}

        if [ $? -ne 0 ]; then
            echoerr "git ${ARGS[@]} was not able to obtain the current remote, does the remote exist?"
            return $?
        fi
        open ${lGIT_URL}
    fi
    return 2

}

function getGitURL() {

    if [ $# -lt 2 ]; then
        tracking=$(${whichGit} for-each-ref --format='%(upstream:short)' $(${whichGit} symbolic-ref -q HEAD)) 2> /dev/null

        DEBUG $0 "tracking - \"${tracking}\" retval: $?"

        if [ $? -ne 0 ]; then
            return $?
        fi

        gitURLArgs[2]=$(echo ${tracking} | cut -f1 -d '/')
        gitURLArgs[3]=$(echo ${tracking} | cut -f2 -d '/')
        unset tracking

    else
        while [[ $2 =~ ^-.+ ]]; do
            shift
        done
        gitURLArgs=($@)
    fi

    if [[ $# -eq 3 ]]; then
        lGIT_BRANCH="tree/${gitURLArgs[3]}"
        DEBUG $0 "lGIT_BRANCH - ${lGIT_BRANCH}"
    fi

    lGIT_URL="$(${whichGit} config --get "remote.${gitURLArgs[2]}.url")/"

    DEBUG $0 "${whichGit} config --get remote.${gitURLArgs[2]}.url returned \"${lGIT_URL}\""
    # If the remote is not found
    if [[ ${lGIT_URL} == "/" ]]; then
        unset lGIT_BRANCH
        return 1
    fi
    # If it is SSH
    if [[ ${lGIT_URL} =~ ^git@github.com:.*$ ]]; then
        lGIT_URL="https://github.com/$(echo $lGIT_URL | cut -f2 -d ':' | rev | cut -f2- -d '.' | rev)/"
    elif [[ ${lGIT_URL} =~ ^https.*@ ]]; then
        lGIT_URL="$(echo lGIT_URL | cut -f1-3 -d '/')/"
        unset lGIT_BRANCH
    fi
    lGIT_URL=${lGIT_URL}${lGIT_BRANCH}
    unset lGIT_BRANCH
    unset gitURLArgs

}
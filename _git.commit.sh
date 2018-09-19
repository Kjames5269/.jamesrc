#!/bin/sh

COMMIT_PREPEND_TAG="-:"

function precommitHook() {
    if [[ $2 != "$COMMIT_PREPEND_TAG" ]]; then
        return 0
    fi

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

    unset currBranch
    unset msg
    unset firstWord
}

function postcommitHook() {
    createLogEntry "commit"
}
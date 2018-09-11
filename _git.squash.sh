#!/usr/bin/env zsh

function presquashHook() {
    if typeset -f checkFetchGuard > /dev/null; then
        checkFetchGuard
    fi

    getFirstJiraCommit

    ${whichGit} reset --soft "${firstJiraCommit}"

    if [ $# -eq 3 ] && [[ $2 == "-m" ]]; then
        FCommit="$3"
    fi

    ARGS=("commit" "-m" "$FCommit")

    cleanupGetFirstJiraCommit

}

function postsquashHook() {
    createLogEntry "squash"
}

function prerebaseHook() {
    if [ $# -ne 3 ]; then
        return 0
    fi

    ARGS=$(${1} "${2}/${3}")

}
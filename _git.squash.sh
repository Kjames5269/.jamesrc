#!/usr/bin/env zsh

function presquashHook() {
    if typeset -f post$1Hook > /dev/null; then
        checkFetchGuard
    fi

    getFirstJiraCommit

    ${whichGit} reset --soft "${firstJiraCommit}"

    if [ $# -eq 3 ] && [[ $2 == "-m" ]]; then
        FCommit="$3"
    fi

    ${whichGit} commit -m "$FCommit"

    ARGS=("commit" "-m" "$FCommit")

}

function prerebaseHook() {
    if [ $# -ne 3 ]; then
        return 0
    fi

    ARGS=$(${1} "${2}/${3}")

}

function postsquashHook() {
    cleanupGetFirstJiraCommit
}
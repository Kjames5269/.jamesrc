#!/bin/sh

function presquashHook() {
    if typeset -f checkFetchGuard > /dev/null; then
        checkFetchGuard
    fi

    C getFirstJiraCommit

    C ${whichGit} reset --soft "${firstJiraCommit}"

    if [ $# -eq 3 ] && [[ $2 == "-m" ]]; then
        FCommit="$3"
    fi

    ARGS=("commit" "-m" "$FCommit")

    C cleanupGetFirstJiraCommit

}

function preprepforHook() {
    git squash
    ARGS[1]="rebase"
    prerebaseHook ${ARGS[@]}
}

function postsquashHook() {
    C createLogEntry "squash"
}

function prerebaseHook() {
    if [ $# -ne 3 ]; then
        return 0
    fi

    ARGS=(${1} "${2}/${3}")

}
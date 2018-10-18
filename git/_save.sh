#!/bin/sh

_GIT_SAVED="Saved"

# Ever had that oh shit moment? Log the current commit you're at with a timestamp
function presaveHook() {
    createLogEntry ${_GIT_SAVED}
    echo "State saved at ${GIT_HOME}/.git/personalCommits.log *making a branch would do this as well :)"
    tail -1 ${GIT_HOME}/.git/personalCommits.log
    return 2
}

function preloadHook() {
    if [ ! -f ${GIT_HOME}/.git/${_GIT_PERSONAL_COMMIT_LOG} ]; then
        echo "No logs within ${GIT_HOME}/.git/${_GIT_PERSONAL_COMMIT_LOG}"
        return 1
    fi

    tuple=$(cut -f3- -d '-' ${GIT_HOME}/.git/${_GIT_PERSONAL_COMMIT_LOG} | egrep "^\ ${_GIT_SAVED}\ --.*$" | tail -1)

    if [ -z ${tuple} ]; then
        echo "No Save points within ${GIT_HOME}/.git/${_GIT_PERSONAL_COMMIT_LOG}"
        return 1
    fi
    commitHash=$(echo ${tuple} | awk -F" -- " '{print $3}')
    savedBranch=$(echo ${tuple} | awk -F" -- " '{print $2}')

    ARGS=("checkout" "${commitHash}")

    GIT_OUTPUT="${GIT_HOME}/tmpOutput"

}

function postloadHook() {
    ${whichGit} branch -f "${savedBranch}" &> ${GIT_OUTPUT}
    ${whichGit} checkout ${savedBranch} &> ${GIT_OUTPUT}
    createLogEntry "Loaded" "-- from ${tuple}"

    echo "Loaded Successfully"
    unset commitHash
    unset savedBranch
    unset tuple
}
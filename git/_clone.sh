#!/bin/sh

gitCloneAutoSSH=1
gitCloneAutoCD=1
# This only works for git clone ${project}

function postcloneHook() {

    if testVar gitCloneAutoSSH || [ ${#ARGS[@]} -ne 2 ]; then
        return
    fi

    tracking=${ARGS[2]}
    C getUserProjTuple ${tracking}

    proj=$(echo ${userProjTuple} | cut -f2 -d '/')


    if C gitIsSSH ${tracking}; then
        DEBUG $0 "Clone'd SSH"
        unset proj userProjTuple
        testVar gitCloneAutoCD && cd ${proj}
        return
    fi

    DEBUG $0 "Clone'd HTTP"
    if ! [[ ${tracking} =~ "^.*github\.com.*$" ]]; then
        DEBUG $0 "Only git repositories are currently supported. (${tracking} does not have github.com within)."
        unset proj userProjTuple
        return 0
    fi

    user=$(echo ${userProjTuple} | cut -f1 -d '/')

    (
        cd ${proj}
        C ${whichGit} remote set-url origin "git@github.com:${user}/${proj}.git"
    )

    testVar gitCloneAutoCD && cd ${proj}

    unset user proj userProjTuple
    unset -f gitCloneCD
}
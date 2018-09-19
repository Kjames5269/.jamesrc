#!/bin/sh

ORIGIN="upstream"
FFORIGIN="0" # Should it assume an origin?

#
# git ff <remote> <branch>
# git ff <remote>/<branch>
#
# Now we get into assumptions
#
# This is short for merge --ff-only and has a few types of ways it can be called after assumptions
# git ff <remote|branch> works
#   - If a branch is given it will try to find the remote by using ${ORIGIN} or simply origin and attempt to ff
#   - If a remote is given it will try to find the current branch on that remote to ff
#
# git ff just does both
#
# Unfortantly with these assumptions, the implementation is not friendly to local fast-forwards between two local branches
# These can be turned off by setting FFORIGIN to 0

function preffHook() {

    ffmerge="merge"
    ffonly="--ff-only"
    fforigin="origin"

    if [ ${#ARGS[@]} -eq 3 ]; then
        ARGS=(${ffmerge} ${ffonly} "${ARGS[2]}/${ARGS[3]}")
    elif [ ${#ARGS[@]} -eq 2 ]; then
        if [[ ${ARGS[2]} =~ ^.*/.* ]] || [[ ${FFORIGIN} -eq 0 ]]; then
            ARGS=(${ffmerge} ${ffonly} "${ARGS[2]}")
        else 
            # if it's not a branch then we're assuming they gave the remote and they want the current branch
            # its a branch then we're assuming they want a remote
            ${whichGit} branch -a | egrep "/${ORIGIN}/${ARGS[2]}$|/origin/${ARGS[2]}$" &> /dev/null
            if [ $? -ne 0 ]; then
                ARGS=(${ffmerge} ${ffonly} "${ARGS[2]}/$(cb)")
            else
                searchForOrigin ${ARGS[2]}
            fi
	fi
    elif [ ${#ARGS[@]} -eq 1 ]; then
        searchForOrigin $(cb)
    else
        echoerr "Invalid use of ff (merge --ff-only) $@"
        echoerr " $ git ff ${ORIGIN}/$(cb)"

        unset ffmerge
        unset ffonly
        unset fforigin

        return $?
    fi

    unset ffmerge
    unset ffonly
    unset fforigin
}

function searchForOrigin() {
    ${whichGit} remote -v | grep ${ORIGIN} &> /dev/null
    if [ $? -eq 0 ]; then
        ARGS=(${ffmerge} ${ffonly} "${ORIGIN}/$1")
    else
        ARGS=(${ffmerge} ${ffonly} "${fforigin}/$1")
    fi
}

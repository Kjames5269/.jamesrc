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
    DEBUG $0 "DEFAULTS :: ORIGIN=$ORIGIN, FFORIGIN=${FFORIGIN}"

    ffmerge="merge"
    ffonly="--ff-only"
    fforigin="origin"

    if [ ${#ARGS[@]} -eq 3 ]; then
        ARGS=(${ffmerge} ${ffonly} "${ARGS[2]}/${ARGS[3]}")
    elif [ ${#ARGS[@]} -eq 2 ]; then
        if [[ ${ARGS[2]} =~ ^.*/.* ]] || ! testVar FFORIGIN; then
            ARGS=(${ffmerge} ${ffonly} "${ARGS[2]}")
        else 
            # if it's not a branch then we're assuming they gave the remote and they want the current branch
            # its a branch then we're assuming they want a remote
            ${whichGit} branch -a | egrep "/${ORIGIN}/${ARGS[2]}$|/origin/${ARGS[2]}$" &> /dev/null
            if [ $? -ne 0 ]; then
                ARGS=(${ffmerge} ${ffonly} "${ARGS[2]}/$(cb)")
            else
                C searchForOrigin ${ARGS[2]}
            fi
	fi
    elif [ ${#ARGS[@]} -eq 1 ]; then
        C searchForOrigin $(cb)
    else
        unset ffmerge
        unset ffonly
        unset fforigin

        echoerr "Invalid use of ff (merge --ff-only) $@"
        echoerr " $ git ff ${ORIGIN}/$(cb)"
        return $?
    fi

    unset ffmerge
    unset ffonly
    unset fforigin
}

function searchForOrigin() {
    # Check to make sure it's not already tracking a branch.
    tracking=$(${whichGit} for-each-ref --format='%(upstream:short)' $(${whichGit} symbolic-ref -q HEAD)) 2> /dev/null
    if [[ ${tracking} != "" ]]; then
        DEBUG $0 "$1 is tracking ${tracking}. Using that as upstream"
        ARGS=(${ffmerge} ${ffonly} ${tracking})
        return
    fi

    ${whichGit} remote -v | grep ${ORIGIN} &> /dev/null
    if [ $? -eq 0 ]; then
        DEBUG $0 "Found ${ORIGIN} in remotes setting to ${ORIGIN}/$1"
        ARGS=(${ffmerge} ${ffonly} "${ORIGIN}/$1")
    else
         DEBUG $0 "Could not find default upstream [${ORIGIN}] using ${fforigin}/$1"
        ARGS=(${ffmerge} ${ffonly} "${fforigin}/$1")
    fi
}

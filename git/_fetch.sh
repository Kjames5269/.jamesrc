#!/bin/sh

TIMELY_FETCH=1
# in minutes

function prefetchHook() {
    gitFetchSetup || return 0
    updateFetchDate
}

function updateFetchDate() {
        echo $(date +'%Y%m%d%H%M') > ${gitDirectory}/CD_LAST_FETCH
}

function checkFetchGuard() {

    C gitFetchSetup || return $?

    if [ -f ${gitDirectory}/FETCH_GUARD ]; then
        DEBUG trace $0 "Guard Exists"

        getPid
        if [[ $myPid == $(head -1 ${gitDirectory}/FETCH_GUARD) ]]; then
            # We are the process who owns the guard (or another process beat us here by a second...)
            DEBUG $0 "${myPid} equals $(head -1 ${gitDirectory}/FETCH_GUARD), we own the guard"
            unset myPid
            return 0
        fi
        unset myPid

        # Incase it locked it before we entered the PID.
        if [ ! -f ${gitDirectory}/FETCH_GUARD ]; then
            DEBUG $0 "Locked the directory before we could put the process to sleep. Good to go"
            return 0
        fi

        echoinf "Fetch is running with PID $(head -1 ${gitDirectory}/FETCH_GUARD), waiting..."

        DEBUG $0 "Adding $$ to the list of waiters inside ${gitDirectory}/FETCH_GUARD."
        echo "$$" >> ${gitDirectory}/FETCH_GUARD
        DEBUG $0 "File is now: \n$(cat ${gitDirectory}/FETCH_GUARD)"

        # sleep infinity pls
        sleep 3600
        wait
    fi

    DEBUG trace $0 "We're done checking ${gitDirectory}/FETCH_GUARD"
}
function gitFetch() {

        DEBUG $0 "Adding our PID to ${gitDirectory}/FETCH_GUARD"

        (getPid && echo ${myPid} > ${gitDirectory}/FETCH_GUARD ;${whichGit} fetch --all &> ${gitDirectory}/lastFetch || echoerr "Failed Fetch" && ${whichGit} diff --quiet && typeset -f preffHook > /dev/null && git ff &> ${gitDirectory}/lastFF; unset myPid)

        wait

        killFetchGuard

        if [ -f ${gitDirectory}/lastFF ]; then
            checkDebug || cat ${gitDirectory}/lastFF
            rm ${gitDirectory}/lastFF
        fi

}

function killFetchGuard() {
#Renaming so a new processes doesn't get locked for some reason between wakeup and removal
        DEBUG $0 "Locking ${gitDirectory}/FETCH_GUARD"
        mv ${gitDirectory}/FETCH_GUARD ${gitDirectory}/FETCH_GUARD.lock

        # Wake up all people waiting on the fetch to finish
        for i in $(tail -n +2 ${gitDirectory}/FETCH_GUARD.lock); do
            DEBUG trace $0 "releasing a lock on the process with PID: $i"
            pkill -P ${i} sleep
        done

        rm ${gitDirectory}/FETCH_GUARD.lock
}

function gitFetchSetup() {
    if [ -z ${GIT_HOME} ]; then
        DEBUG $0 "GIT_HOME is not set"
        return 1
    elif [ -f "${GIT_HOME}/.git" ]; then
        gitDirectory=$(cat "${GIT_HOME}/.git")
    elif [ -d "${GIT_HOME}/.git" ]; then
        gitDirectory="${GIT_HOME}/.git"
    else
        unset whichGit
        unset GIT_HOME
        return 1
    fi
}

function autoFetch() {

    gitWrapSetup
    gitFetchSetup || return 0

    if [ -f "${gitDirectory}/CD_LAST_FETCH" ]; then
        lastFetch=$(cat "${gitDirectory}/CD_LAST_FETCH")
        currDate=$(date +'%Y%m%d%H%M')
        if [[ $(($currDate - $lastFetch)) -lt $TIMELY_FETCH ]]; then
            return 0
        fi
    fi

    echo $(date +'%Y%m%d%H%M') > ${gitDirectory}/CD_LAST_FETCH

    ( gitFetch & ) # 2>/dev/null

    unset lastFetch
    unset currDate
    unset gitDirectory
}

environment=$(echo ${SHELL} | rev | cut -f1 -d '/' | rev)

case ${environment} in
    "zsh")
        # TODO:: Make this into a function hook.
        function precmd() {
            autoFetch
        }
        ;;
    "bash")
        PROMPT_COMMAND="${PROMPT_COMMAND}autoFetch;"
        ;;
    *)
        echoerr "$environment is currently not supported"
        ;;
esac
unset environment

alias cd=cdWrap

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

    if [ -f ${gitDirectory}/FETCH_GUARD ]; then
        getPid
        if [[ $myPid == $(head -1 ${gitDirectory}/FETCH_GUARD) ]]; then
            # We are the process who owns the guard (or another process beat us here by a second...)
            unset myPid
            return 0
        fi
        unset myPid

	# Incase it locked it before we entered the PID.
	if [ -f ${gitDirectory}/FETCH_GUARD ]; then
		return 0
	fi

        echoinf "Fetch is running with PID $(head -1 ${gitDirectory}/FETCH_GUARD), waiting..."

        echo "$$" >> ${gitDirectory}/FETCH_GUARD
        # sleep infinity pls
        sleep 3600
        wait
    fi

}
function gitFetch() {

        (getPid && echo ${myPid} > ${gitDirectory}/FETCH_GUARD ;${whichGit} fetch --all > ${gitDirectory}/lastFetch; unset myPid)

        wait

        killFetchGuard

        if [[ $(grep -i ^Fetched ${gitDirectory}/lastFetch) != "" ]]; then
            tput sc && tput cuf 300 && echo -e "\033[01;35m!\033[0m" && tput rc
        fi

}

function killFetchGuard() {
#Renaming so a new processes doesn't get locked for some reason between wakeup and removal
        mv ${gitDirectory}/FETCH_GUARD ${gitDirectory}/FETCH_GUARD.lock

        # There's no one waiting on us so nobody needs these variables.
        if [ $(wc -l ${gitDirectory}/FETCH_GUARD.lock) -eq 1 ]; then
            unset GIT_HOME
            unset whichGit
        fi

        # Wake up all people waiting on the fetch to finish
        for i in $(tail -n +2 ${gitDirectory}/FETCH_GUARD.lock); do
            pkill -P ${i} sleep
        done

        rm ${gitDirectory}/FETCH_GUARD.lock
}

function gitFetchSetup() {
    if [ -f "${GIT_HOME}/.git" ]; then
        # echo "This is a file...?"
        gitDirectory=$(cat "${GIT_HOME}/.git")
    elif [ -d "${GIT_HOME}/.git" ]; then
        # echo "Ahh a directory, as it should be"
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

    ( gitFetch & ) 2>/dev/null

    unset lastFetch
    unset currDate
    unset gitDirectory
}

environment=$(echo ${SHELL} | rev | cut -f1 -d '/' | rev)

case ${environment} in
    "zsh")
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

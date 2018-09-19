#!/bin/sh

TIMELY_FETCH=1
# in minutes

function prefetchHook() {
    updateFetchDate

}

function updateFetchDate() {
        echo $(date +'%Y%m%d%H%M') > ${GIT_HOME}/.git/CD_LAST_FETCH
}

function checkFetchGuard() {

    if [ -f ${GIT_HOME}/.git/FETCH_GUARD ]; then
        getPid
        if [[ $myPid == $(head -1 ${GIT_HOME}/.git/FETCH_GUARD) ]]; then
            # We are the process who owns the guard (or another process beat us here by a second...
            unset myPid
            return 0
        fi
        unset myPid
        echoinf "Fetch is running with PID $(head -1 ${GIT_HOME}/.git/FETCH_GUARD), waiting..."

        echo "$$" >> ${GIT_HOME}/.git/FETCH_GUARD
        # sleep infinity pls
        sleep 3600
        wait
    fi

}
function gitFetch() {

        (getPid && echo ${myPid} > ${GIT_HOME}/.git/FETCH_GUARD ;${whichGit} fetch --all > ${GIT_HOME}/.git/lastFetch; unset myPid)

        wait

        killFetchGuard

        if [[ $(grep -i ^Fetched ${GIT_HOME}/.git/lastFetch) != "" ]]; then
            tput sc && tput cuf 300 && echo -e "\033[01;35m!\033[0m" && tput rc
        fi

}

function killFetchGuard() {
#Renaming so a new processes doesn't get locked for some reason between wakeup and removal
        mv ${GIT_HOME}/.git/FETCH_GUARD ${GIT_HOME}/.git/FETCH_GUARD.lock

        # There's no one waiting on us so nobody needs these variables.
        if [ $(wc -l ${GIT_HOME}/.git/FETCH_GUARD.lock) -eq 1 ]; then
            unset GIT_HOME
            unset whichGit
        fi

        # Wake up all people waiting on the fetch to finish
        for i in $(tail -n +2 ${GIT_HOME}/.git/FETCH_GUARD.lock); do
            pkill -P ${i} sleep
        done

        rm ${GIT_HOME}/.git/FETCH_GUARD.lock
}
function autoFetch() {

    gitWrapSetup

    if [ -d "${GIT_HOME}" ]; then
        if [ -f "${GIT_HOME}/.git/CD_LAST_FETCH" ]; then
            lastFetch=$(cat "${GIT_HOME}/.git/CD_LAST_FETCH")
            currDate=$(date +'%Y%m%d%H%M')
            if [[ $(($currDate - $lastFetch)) -lt $TIMELY_FETCH ]]; then
                return 0
            fi
        fi

        echo $(date +'%Y%m%d%H%M') > ${GIT_HOME}/.git/CD_LAST_FETCH

        ( gitFetch & ) 2>/dev/null

        unset lastFetch
        unset currDate
    else
        unset whichGit
        unset GIT_HOME
    fi
}

function cdWrap() {

    if [ $# -ne 0 ] && [ -f $1 ] && [[ $(echo $1 | egrep "/src/") != "" ]]; then
        cd $(echo $1 | awk -F"/src/" '{print $1}')
    else
        cd $1
    fi
    autoFetch
}

alias cd=cdWrap

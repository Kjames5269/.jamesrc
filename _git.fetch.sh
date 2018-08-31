#!/usr/bin/env zsh

function prefetchHook() {
    updateFetchDate

}

function updateFetchDate() {
        echo $(date +'%Y%m%d%H%M') > '.git/CD_LAST_FETCH'
}

function checkFetchGuard() {

    if [ -f '.git/FETCH_GUARD' ]; then
        if [[ $sysparams[pid] == $(head -1 '.git/FETCH_GUARD') ]]; then
            # We are the process who owns the guard (or another process beat us here by a second...
            return 0
        fi
        echoinf "Fetch is running with PID $(head -1 '.git/FETCH_GUARD'), waiting..."

        echo "$$" >> '.git/FETCH_GUARD'
        # sleep infinity pls
        sleep 3600
        wait
    fi

}
function gitFetch() {

        (echo $sysparams[pid] > '.git/FETCH_GUARD' ;${whichGit} fetch --all > '.git/lastFetch')

        wait

        killFetchGuard

        if [[ $(grep -i ^Fetched .git/lastFetch) != "" ]]; then
            tput sc && tput cuf 300 && echo -e "\033[01;35m!\033[0m" && tput rc
        fi
}

function killFetchGuard() {
#Renaming so a new processes doesn't get locked for some reason between wakeup and removal
        mv '.git/FETCH_GUARD' '.git/FETCH_GUARD.lock'

        # Wake up all people waiting on the fetch to finish
        for i in $(tail -n +2 '.git/FETCH_GUARD.lock'); do
            pkill -P ${i} sleep
        done

        rm '.git/FETCH_GUARD.lock'
}
function autoFetch() {
    if [ -d .git ]; then
        if [ -f '.git/CD_LAST_FETCH' ]; then
            lastFetch=$(cat '.git/CD_LAST_FETCH')
            currDate=$(date +'%Y%m%d%H%M')
            if [[ $(($currDate - $lastFetch)) -lt $TIMELY_FETCH ]]; then
                return 0
            fi
        fi

        echo $(date +'%Y%m%d%H%M') > '.git/CD_LAST_FETCH'

        ( gitFetch & ) 2>/dev/null

        unset lastFetch
        unset currDate
    fi
}

function cdWrap() {

    if [ -f $1 ]; then
        cd $(echo $1 | rev | cut -f2- -d '/' | rev )
    else
        cd $1
    fi
    autoFetch
}

alias cd=cdWrap
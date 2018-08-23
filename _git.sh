#!/bin/zsh

alias cb="/usr/bin/git rev-parse --abbrev-ref HEAD"
alias cc="/usr/bin/git rev-parse HEAD"

TIMELY_FETCH=1
# in minutes

COMMIT_PREPEND_TAG="-:"

# A git wrapper just so you can pass cb as current branch to any command
# To get the auto completion scripts shamelessly steal them from the hub github using... TODO

unalias git
whichGit=$(which git)

function gitWrap() {

    if [ -z ${whichGit} ]; then
        whichGit=$(which git)
    fi

    GIT_HOME=$(${whichGit} rev-parse --show-toplevel)
    if [ $? -ne 0 ]; then
        return 1
    fi

	if [[ ${@: -1} == "cb" ]]; then
		length=$(($# - 1))

		currBranch=$(cb)

		ARGS=(${@:1:$length} $currBranch)
    else
        ARGS=($@)
    fi


    if [[ $1 == "push" ]]; then
        getGitURL ${ARGS[@]}

    elif [[ $1 == "pub" ]]; then
        getGitURL ${ARGS[@]}
        ARGS[1]="push"
        openOnSuccess=1

	elif [[ $1 == "add" ]]; then

        if [ -f "${GIT_HOME}/pom.xml" ]; then

            if [ -e $2 ]; then
                # This isn't perfect but it should be "good enough"
                listOfChanged=($(${whichGit} ls-files -m  | grep /src/ | grep $2 | awk -F"/src/" '{print $1}' | uniq))
            elif [ $# -eq 2 ]; then
                #listOfChanged=($(${whichGit} status --short | grep /src/ | awk -F"/src/" '{print $1}' | cut -c4- | uniq))
                listOfChanged=($(${whichGit} ls-files -m | grep /src/ | awk -F"/src/" '{print $1}' | uniq))
            else
                echoerr "This is not yet implemented. Add one file at a time"
                return $?
            fi

            mavenFmtDirName="${GIT_HOME}/.git/_GIT_MAVEN_FORMATTING/"

            if [ ${#listOfChanged[@]} -gt 0 ]; then

                mkdir ${mavenFmtDirName}

                for i in ${listOfChanged[@]}; do
                    ( mvnFmt ${GIT_HOME}/${i} & )
                done

                # R A C E  C O N D I T I O N S
                # This is unfortunately done because I want quiet terminals
                # that are not cluttered with PID's of background processes
                # This however means that there is no way to wait for the child
                # since the child is technically done... So this was the alternative
                sleep 1

                while [ $(/bin/ls ${mavenFmtDirName} | wc -l) -ne 0 ]; do
                    sleep .25
                done

                rm -d ${mavenFmtDirName}

                if [ ! -z ${mvnFmtError} ]; then
                    unset mvnFmtError
                    echoerr "One or more formatting errors occurred. Nothing was added"
                    return $?
                fi

            fi

        fi

		ARGS=(${@})

    elif [[ $1 == "commit" ]] && [[ $2 == "$COMMIT_PREPEND_TAG" ]]; then

        length=$(($# - 1))

        currBranch=$(cb | cut -f1,2 -d '-' )

        # git (1)commit -: commit message starts at 3
        msg=$(echo ${@:3:$#})

        if [ $? -ne 0 ]; then
            return 1
        fi

        firstWord=$(echo ${msg} | cut -f1 -d ' ')

        if [[ "$firstWord" != "$currBranch" ]]; then
            ARGS=("${1}" "-m" "${currBranch} ${msg}")
        else
            ARGS=("${1}" "-m" "\"${msg}\"")
        fi

    elif [[ $1 == "fetch" ]]; then
        updateFetchDate
        ARGS=(${@})

    elif [[ $1 == "squash" ]]; then

        checkFetchGuard

        getFirstJiraCommit

        ${whichGit} reset --soft "${firstJiraCommit}"

        if [ $# -eq 3 ] && [[ $2 == "-m" ]]; then
            FCommit="$3"
        fi

        ${whichGit} commit -m "$FCommit"

        return $?

    elif [ $# -eq 3 ] && [[ $1 == "rebase" ]]; then
        ARGS=$(${1} "${2}/${3}")

    elif [[ $1 == "request" ]]; then
        if [ $# -eq 1 ] && ! [ -z ${lGIT_URL} ]; then
            open ${lGIT_URL}
        elif [ $# -gt 1 ]; then
            unset lGIT_URL
            getGitURL $@
            if [ -z ${lGIT_URL} ]; then
                echoerr "git $@ was not successful does the remote exist?"
                return $?
            fi
            open ${lGIT_URL}
        else
            echoerr "git $@ was not able to obtain the last remote, did you push on this terminal?"
            return $?
        fi
        return 0

	else
		ARGS=(${@})
	fi

    checkFetchGuard

    which hub > /dev/null
    if [ $? -eq 0 ]; then
	    hub ${ARGS[@]}
	else
		${whichGit} ${ARGS[@]}
	fi

    if [ $? -eq 0 ] && [ ${openOnSuccess} -eq 1 ]; then
        unset openOnSuccess
        open ${lGIT_URL}
    fi

	# remove all set variables
	unset ARGS
	unset mavenFmtDirName
	unset firstJiraCommit
    unset listOfChanged
    unset GIT_HOME
    unset length
    unset currBranch
    unset msg
    unset FCommit
    unset FTag
    unset oldIFS

}

function getGitURL() {

    if [ $# -lt 2 ]; then
        return 1
    fi

    while [[ $2 =~ ^-.+ ]]; do
        shift
    done

    if [[ $# -eq 3 ]]; then
        lGIT_BRANCH="tree/$3"
    fi

    lGIT_URL=$(${whichGit} config --get "remote.${2}.url")
    # If it is SSH
    if [[ ${lGIT_URL} =~ ^git@github.com:.*$ ]]; then
        lGIT_URL="https://github.com/$(echo $lGIT_URL | cut -f2 -d ':' | rev | cut -f2- -d '.' | rev)/"
    elif [[ ${lGIT_URL} =~ ^https.*@ ]]; then
        lGIT_URL=$(echo lGIT_URL | cut -f1-3 -d '/')
        unset lGIT_BRANCH
    fi
    lGIT_URL=${lGIT_URL}${lGIT_BRANCH}
    unset lGIT_BRANCH

}
function mvnFmt() {
    if ! [ -d $1 ]; then
        return 0
    fi

    mkdir ${mavenFmtDirName}$sysparams[pid]

    echoinf "mvn fmt: $1"

    cd $1
    mvn fmt:format &> /dev/null

    if [ $? -ne 0 ]; then
        echoerr "> mvn fmt:format"
        echoerr "did not work in ${1}"
        mvnFmtError="Gah"
    fi

    rm -d ${mavenFmtDirName}$sysparams[pid]
}

function getFirstJiraCommit() {
    oldIFS=$IFS
    IFS=$'\n'
    for i in $(${whichGit} log --format="%H %s"); do
        if [ -z $FCommit ]; then

            FCommit=$(echo $i | cut -f2- -d ' ')
            FTag=$(echo $i | cut -f2 -d ' ')
            continue
        fi
        #echo "$i"

        CTag=$(echo $i | cut -f2 -d ' ')

        if [[ ${CTag} != ${FTag} ]]; then

            firstJiraCommit=$(echo $i | cut -f1 -d ' ')
            break
        fi
        FCommit=$(echo $i | cut -f2- -d ' ')

    done
    IFS=$oldIFS
}

alias git=gitWrap

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

        if [[ $(grep 'Unpacking objects:' .git/lastFetch) != "" ]]; then
            echo -n "!" >&2
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

        ( gitFetch & ) 2>/dev/null

        echo $(date +'%Y%m%d%H%M') > '.git/CD_LAST_FETCH'
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

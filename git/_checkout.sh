#!/bin/sh

function precheckoutHook() {

    if [ $# -ne 2 ] || ! [[ $2 =~ : ]]; then
        return 0
    fi

    if [[ $2 =~ ^:$ ]]; then

        neighborBranch=$(${whichGit} branch | grep $(cb | cut -f1,2 -d '-') | grep -v \*)
        DEBUG $0 "Found neighbor ${neighborBranch}"

        if [[ ${neighborBranch} == "" ]]; then
            echoerr "git $@ has no neighbor branch"
            return $?
        elif [ $(echo ${neighborBranch} | wc -w) -ne 1 ]; then
            echoerr "git $@ has too many neighbor branches"
            return $?
        fi
        ARGS=($1 $(echo ${neighborBranch} | cut -c3-))
    elif [[ $2 =~ ^:[^-].*$ ]]; then
        baseBranch=$(${whichGit} branch | grep \* | cut -c3- | cut -f1,2 -d '-')
        extension=$(echo $2 | cut -c2-)
        neighborBranch=$(${whichGit} branch | grep ${baseBranch}-${extension})
        DEBUG $0 "Found neighbor ${neighborBranch}"

        if [ $? -ne 0 ]; then
            neighborBaseBranch=$(${whichGit} branch | grep "^ *"${extension}"$" | cut -c3-)
            if [[ ${neighborBaseBranch} == "" ]]; then
                echoerr "git $@ did not find a base branch to create a neighbor from"
                return $?
            fi

            C getFirstJiraCommit

            DEBUG $0 ">> ${whichGit} checkout -b ${baseBranch}-${extension}"
            ${whichGit} checkout -b "${baseBranch}-${extension}"
            if [ $? -ne 0 ]; then
                return $?
            fi
            ARGS=("rebase" "--onto" "${neighborBaseBranch}" "${firstJiraCommit}")
        else
            ARGS=($1 ${neighborBranch})
        fi
    elif [[ $2 =~ "^:.+$" ]]; then
        baseBranch=$(${whichGit} branch | grep \* | cut -c3-)
        count=$(echo ${baseBranch} | tr -cd '-' | wc -c)
        if [ ${count} -le 1 ]; then
            echoerr "git $@ requires you to be on a nonBase branch"
            return $?
        fi

        C getFirstJiraCommit

        neighborBranch=$(echo ${baseBranch} | cut -f1-${count// /} -d '-')

        DEBUG $0 ">> ${whichGit} checkout -b ${baseBranch}-${extension}"
        ${whichGit} checkout -b ${neighborBranch}
        if [ $? -ne 0 ]; then
            return $?
        fi

        ARGS=("rebase" "--onto" "master" "${firstJiraCommit}")

    elif [[ $2 =~ "^.+:.+$" ]]; then

        DEBUG $0 "check out PR format"

        user=$(echo $2 | cut -f1 -d ':')
        branch=$(echo $2 | cut -f2 -d ':')

        # Setup the argument since it won't change from here.
        ARGS=("checkout" "${branch}")

        # Get all the remotes looking for the first half of the message: The user
        for i in $(${whichGit} remote -v | awk '{print $2}' | uniq); do
            DEBUG trace $0 "Looping through remotes $i"

            C getUserProjTuple $(echo "${i}")
            iUser=$(echo ${userProjTuple} | cut -f1 -d '/')

            if [[ ${user} == ${iUser} ]]; then
                DEBUG $0 "Found ${user}"
                return 0
            fi
        done

        project=$(echo ${userProjTuple} | cut -f2 -d '/')

        DEBUG $0 "Adding ${user} as a remote"

        C ${whichGit} remote add ${user} "https://github.com/${user}/${project}"

        DEBUG $0 "Fetching branches from ${user}"

        ${whichGit} fetch ${user} &> /dev/null

    fi

}

postcheckoutHook() {
    cleanupGetFirstJiraCommit
    unset baseBranch
    unset count
    unset neighborBranch
    unset extension
    unset user iUser userProjTuple branch

}
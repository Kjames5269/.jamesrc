#!/usr/bin/env sh

if ! [ -f ${JRC_GIT_NAMES} ]; then
    echo "" > "${JRC_GIT_NAMES}"
fi

function preremoteHook() {
    if [[ ${ARGS[2]} != "add" ]] && [ ${#ARGS[@]} -le 2 ]; then
        return 0
    fi

    # TODO add in bitbucket compatibility

    name=$(egrep "^${ARGS[3]}:" ${JRC_GIT_NAMES} | cut -f2 -d ':')
    DEBUG $0 "LF ${ARGS[3]}, found \"${name}\""

    # remote add name "URL"
    if [ ${#ARGS[@]} -eq 3 ]; then

        test -z ${name} && return $(echoerr "${ARGS[3]} was not in the list of known names")

        C getUserProj $(${whichGit} config --get remote.origin.url)
        remoteProjectName=$(echo ${userAndProj} | cut -f2 -d '/')

        ARGS[4]="https://github.com/${name}/${remoteProjectName}"

        DEBUG $0 "Remote project found is ${remoteProjectName}, URL is :: ${ARGS[4]}"

    elif [ ${#ARGS[@]} -eq 4 ]; then

        C getUserProj ${ARGS[4]}
        gitName=$(echo ${userAndProj} | cut -f1 -d '/')

        if [[ "${gitName}" == "${name}" ]]; then
            DEBUG $0 "Names matched! ${gitName}. HTTPS auto-completion is a thing."
            return 0
        fi

        if [ -z ${name} ]; then
            echo "${ARGS[3]}:${gitName}" >> ${JRC_GIT_NAMES}
            DEBUG $0 "Adding ${ARGS[3]}:${gitName} to ${JRC_GIT_NAMES}"
        else
            echoinf "updating the alias: ${gitName} from ${name} to ${gitName}..."
            sed -i '' 's/'"${ARGS[3]}:${name}"'/'"${ARGS[3]}:${gitName}"'/' ${JRC_GIT_NAMES}
        #https://github.com/{user}/{project}
        fi
    fi
}

function getUserProj() {
    if [[ ${1} =~ "^.*\.git$" ]]; then
    # If the remote is ssh it has the following format git@github.com:User/proj.git
        userAndProj=$(echo ${1} | rev | cut -f1 -d ':' | cut -f2- -d '.' | rev)
    else
    # It'll be https://github.com/User/proj
        userAndProj=$(echo ${1} | rev | cut -f1,2 -d '/' | rev)
    fi
    DEBUG $0 "Returning ${userAndProj}"
}
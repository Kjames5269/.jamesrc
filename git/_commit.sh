#!/bin/sh

COMMIT_PREPEND_TAG="-:"

function precommitHook() {
    if [[ $2 != "$COMMIT_PREPEND_TAG" ]]; then
        return 0
    fi

    length=$(($# - 1))

    currBranch=$(cb | cut -f1,2 -d '-' )

    DEBUG $0 "Current Branch is ${currBranch}"

    # git (1)commit -: commit message starts at 3
    msg="$(echo ${@:3:$#})"

    if [ $? -ne 0 ]; then
        return 1
    fi

    C stringReplace ${msg}
    msg=${retval}
    unset retval

    firstWord=$(echo ${msg} | cut -f1 -d ' ')

    if [[ "$firstWord" != "$currBranch" ]]; then
        ARGS=("${1}" "-m" "${currBranch} ${msg}")
    else
        ARGS=("${1}" "-m" "\"${msg}\"")
    fi

    unset currBranch
    unset msg
    unset firstWord
}

function postcommitHook() {
    createLogEntry "commit"
}

function stringReplace() {

    local mapping=(
        "@this:#$(echo ${currBranch} | cut -f2 -d '-' | awk '$0*=1')"
        "@This:#$(echo ${currBranch} | cut -f2 -d '-' | awk '$0*=1')"
        "@this.:#$(echo ${currBranch} | cut -f2 -d '-' | awk '$0*=1')."
        "@This.:#$(echo ${currBranch} | cut -f2 -d '-' | awk '$0*=1')."
        "@this,:#$(echo ${currBranch} | cut -f2 -d '-' | awk '$0*=1'),"
        "@This,:#$(echo ${currBranch} | cut -f2 -d '-' | awk '$0*=1'),"
    )
    # '#this' will assume the numbers are an issue and replace it.

    local builtMsg=""
    for i in $(echo ${1} | cat); do
        DEBUG "trace" $0 "${builtMsg} '${i}'"
        local found=0

        for j in ${mapping[@]}; do
            local key=${j%%:*}
            local val=${j#*:}
            DEBUG "trace" $0 "${i} :: ${key}"

            if [[ "${i}" == "${key}" ]]; then
                builtMsg="${builtMsg} ${val}"
                found=1
                break
            fi
        done
        if [ ${found} -eq 0 ]; then
            builtMsg="${builtMsg} ${i}"
        fi

    done

    retval=$(echo ${builtMsg} | awk '{$1=$1;print}')
    DEBUG $0 "${retval}"

}
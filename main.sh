#!/bin/sh

function toBinary() {
    echo "obase=2;$1" | bc
}

function getRWX() {
    stat -f "%A" $1
}

function getOwner() {
    stat -f '%Su' $1
}

function checkFileSafety() {

    # Check writeability.
    local rwx=$(getRWX $1)
    local g=$(echo ${rwx} | cut -c2)
    local a=$(echo ${rwx} | cut -c3)

    local wg=$(toBinary ${g} | cut -c2)
    local wa=$(toBinary ${a} | cut -c2)

    # If someone can write to the file. No good
    if [ ${wg} -eq 1 ] || [ ${wa} -eq 1 ]; then
        return 1
    fi

    local owner=$(getOwner $1)

    # You or the root must be the owner.
    if [[ ${owner} != $(whoami) ]] && [[ ${owner} != "root" ]]; then
        return 1
    fi

    return 0

}

# Setup Files
JRC_BASE_PATH="$(dirname $0)/"
if ! checkFileSafety "${JRC_BASE_PATH}.."; then
    echo "$0 is in a directory that can be modified. It's unwise to source a script in a public place"
    echo "Consider running one of the following: "
    echo "> mv ${JRC_BASE_PATH}/ ${HOME}/"
    echo "or"
    echo "> sudo chown $(echo ${JRC_BASE_PATH} | rev | cut -f3- -d '/' | rev) root"
    return 1
fi

source "${JRC_BASE_PATH}.metadata/fileNames.sh"

jrcSafetyFlag=0

for i in $(find ${JRC_BASE_PATH} -name '_*.sh'); do
    if checkFileSafety ${i}; then
	    source ${i}
	else
	    echo "Ignoring ${i}..."
	    jrcSafetyFlag=1
	fi
done

if [ ${jrcSafetyFlag} -eq 1 ]; then
    echo "One or more files have not been sourced due to their file permissions"
fi
unset jrcSafetyFlag

function getPid() {
    environment=$(echo ${SHELL} | rev | cut -f1 -d '/' | rev)

    case ${environment} in
        "zsh")
            myPid=${sysparams[pid]}
            ;;
        "bash")
            if [ -z $BASHPID ]; then
                echoerr "$environment 3 is not supported (consider upgrading to $environment 4)"
                unset environment
                return
            fi
            myPid=$BASHPID
            ;;
        *)
            echoerr "$environment is currently not supported"
            ;;
    esac
    unset environment
}

getPid
unset myPid


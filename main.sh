#!/bin/sh

for i in $(/bin/ls /Users/$(whoami)/.jamesrc/_*.sh); do
	source $i
done

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
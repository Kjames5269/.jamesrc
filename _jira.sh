#!/bin/bash

# This requires the Jira plugin to be installed on oh-my-zsh
# ( or a pre-existing jira command that takes the same arguments )
# JIRA Wrapper 

JIRA_URL="https://codice.atlassian.net"
DJIRA_USR="kyle.grady"

# See other commands in oh-my-zsh/plugins/jira
DEFAULT_DJIRA_ARG="branch"

# This uses two files:
#   .workspaceJira
#   .workspaceNicknames
#
# .workspaceJira has the following format:
# JiraURL:ProjectName:JiraName
#
# .workspaceNicknames has the following format
# nickname:JiraName

djira() {

	if [[ $1 == "--help" ]]; then
		echoinf "djira is a wrapper for the jira plugin for oh-my-zsh"
		echoinf "it allows you to more easily have more than one jira repo"
		echoinf "djira ddf <cmd> or djira ddf-3952"
		echoinf "cmds: <new> <dashboard> <(reported user)> <(assigned user)> <branch>"
		return 0
	fi
	
	if [ -f ~/.jamesrc/.workspaceJira ]; then
		JIRA_ARR=($(cat ~/.jamesrc/.workspaceJira))
	fi
	
	if [[ JIRA_ARR == "" ]]; then
		echoinf TODO: Set up auto jira
		return 0
	fi

	# If it's a git branch then guess the project
    if [[ -d .git ]]; then
        PROJ=$(pwd | rev | cut -f1 -d '/' | rev)

        DJIRA_TUPLE=$(grep ${PROJ} ~/.jamesrc/.workspaceJira)
        DJIRA_URL=$(echo ${DJIRA_TUPLE} | cut -f1,2 -d 'd')
        DJIRA_USR=$(echo ${JIRA_ARR[$i]} | cut -f4 -d ':')

	fi
	
	FOUND=0
	# Matches anything - one or more numbers
	# DDF-3636
	if ! [[ $1 =~ ^.*-[0-9]+ ]]; then
		# If its found in the file we need to shift after setting the directorys

		FOUND=1
	fi

	# Even if it's a git branch override it if its given
	# Loops through all Jira configs and see's if we match. If not use standard as it's probably a command
	for (( i = 1; i < ${#JIRA_ARR[@]} + 1 ; ++i)) do
		
		JIRA_REPO=$(echo ${JIRA_ARR[$i]} | cut -f3 -d ':')
		
		if [ $FOUND -eq -1 ]; then
			ARG_NAME=$(echo $1 | cut -f1 -d '-')
		else
			ARG_NAME=$1
		fi

		if [[ ${JIRA_REPO} == ${ARG_NAME} ]];then
			PROJ=$1
			DJIRA_URL=$(echo ${JIRA_ARR[$i]} | cut -f1,2 -d ':')
			DJIRA_USR=$(echo ${JIRA_ARR[$i]} | cut -f4 -d ':')

			if [ $FOUND -eq 1 ]; then
				shift
			fi

            # fixes typo's (hopefully typo's) ddf 4242
			if [[ $1 =~ ^[0-9]+$ ]]; then
			    1=${JIRA_REPO}-$1
			fi

			break
		fi
	done

    # If there are two arguments at this point its a user query
    # grep the file looking for nickname: if there's a match replace it with the full name
	if [ $# -eq 2 ] && [ -f ~/.jamesrc/.workspaceNicknames ] ; then
	    potentialName=$(grep -i ${2}: ~/.jamesrc/.workspaceNicknames | cut -f2 -d ':')

        if [ ! -z ${potentialName} ]; then
            DJIRA_USR=${potentialName}
        else
            DJIRA_USR=${2}
        fi

	fi

	# The default argument
	if [ $# -eq 0 ]; then
		ARGS="$DEFAULT_DJIRA_ARG"
	else
		ARGS=$1
	fi

	if [ ! -z $DJIRA_URL ]; then
        	JIRA_NAME=${DJIRA_USR} JIRA_URL=${DJIRA_URL} jira ${ARGS}
	else
		JIRA_NAME=${DJIRA_USR} jira ${ARGS}
	fi
}
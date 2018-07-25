#!/bin/bash

# This requires the Jira plugin to be installed on oh-my-zsh
# ( or a pre-existing jira command that takes the same arguments )
# JIRA Wrapper 

JIRA_URL="https://codice.atlassian.net"

# See other commands in oh-my-zsh/plugins/jira
DEFAULT_DJIRA_ARG="branch"


djira() {
	
	if [ -f ~/.jamesrc/.workspaceJira ]; then
		JIRA_ARR=($(cat ~/.jamesrc/.workspaceJira))
	fi
	
	if [[ JIRA_ARR == "" ]]; then
		echoinf TODO: Set up auto jira
		return 0
	fi

	FLAG=0
	# If it's a git branch then guess the project
        if [[ -d .git ]]; then
                PROJ=$(pwd | rev | cut -f1 -d '/' | rev)
		DJIRA_URL=$(grep ${PROJ} ~/.jamesrc/.workspaceJira | cut -f1,2 -d 'd')
        	
		FLAG=1
	fi

	# Matches anything - one or more numbers
	# DDF-3636
	if ! [[ $1 =~ ^.*-[0-9]+ ]]; then
		
		if [ $FLAG -eq 0 ]; then
			echoerr "$1 is not a valid command or you are not in a git directory, djira ddf-5269"
			return 1
		fi
	fi

	# Even if it's a git branch override it if its given
	# Loops through all Jira configs and see's if we match. If not use standard as it's probably a command
	for (( i = 1; i < ${#JIRA_ARR[@]} + 1 ; ++i)) do
		
		JIRA_NAME=$(echo ${JIRA_ARR[$i]} | cut -f3- -d ':')		
		
		ARG_NAME=$(echo $1 | cut -f1 -d '-')

		if [[ ${JIRA_NAME} == ${ARG_NAME} ]];then
			PROJ=$1
			DJIRA_URL=$(echo ${JIRA_ARR[$i]} | cut -f1,2 -d ':')

			break
		fi
	done

	# The default argument
	if [ $# -eq 0 ]; then
		ARGS="$DEFAULT_DJIRA_ARG"
	else
		ARGS=$@
	fi

	if [[ $DJIRA_URL != "" ]]; then
        	JIRA_URL=$DJIRA_URL jira $ARGS
	else
		jira $ARGS
	fi
}

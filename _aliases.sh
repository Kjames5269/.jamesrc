#!/usr/bin/env bash
OPENED_AT=$(pwd)

#Aliases
alias nt="open -a Terminal `pwd`"
alias ll="ls -l"
alias la="ls -la"
alias diretide="echo '༼ つ ◕_◕ ༽つ' | pbcopy"
alias shrug="echo '¯\_(ツ)_/¯' | pbcopy"
alias cdhome="cd $OPENED_AT"
alias mvnerr="cat ~/lastbuild.log"
alias ip="ifconfig | grep 'inet ' | grep -Fv 127.0.0.1 | cut -f2 -d ' '"

#functions
mkcd () {
	mkdir -p $1 && cd $1
}

ij () {
	if [ $# -eq 1 ] && [ -d $1  ]; then
		openDir=$1
	elif [ ! -d $1 ]; then
		echoerr "$1 is an invalid directory"
		return 1
	else
		openDir=$(pwd)
	fi
	/usr/local/bin/idea $openDir
}

mvnhome() {

	OLD_DIR=`pwd`
	
	cd "$OPENED_AT"
	MVNCMD=($(cat ~/.jamesrc/.workspaceDefaultMaven))
    mvn clean install ${MVNCMD[*]} ${@}

	cd "$OLD_DIR"
}

#Set up global Variables
if [ -f ~/.jamesrc/.workspaceLocationFile ]; then
	WORKSPACE=$(cat ~/.jamesrc/.workspaceLocationFile)

	# Creates an alias to cd to a directory in projects: iddf
	# creates a variable to the project for use in shell. ij $ddf
	for file in $( ls $WORKSPACE ); do
		tfile=$(echo "$file" | tr - _)
		if [ -f "${WORKSPACE}${file}/build.config" ]; then
		    temp=$(grep "master=" ${WORKSPACE}${file}/build.config | cut -f2 -d '=')
		    alias i${tfile}="cd ${WORKSPACE}${file}/${temp}"
		    export ${tfile}="${WORKSPACE}${file}/${temp}"

		else
		    alias i${tfile}="cd ${WORKSPACE}${file}"
		    export ${tfile}="${WORKSPACE}${file}"

		fi

		# If it exist in the lib directory
		if [ -d ${WORKSPACE}../lib/${file} ]; then 
			alias l${tfile}="cd ${WORKSPACE}../lib/${file}"
		fi
	done
	
	alias pls="ls $WORKSPACE"
	alias workspace="cd $WORKSPACE"
	alias proj="cd $WORKSPACE"
fi

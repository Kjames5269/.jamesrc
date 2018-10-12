#!/bin/sh
OPENED_AT=$(pwd)

PathToIntelliJ="/usr/local/bin/idea"

#Aliases
alias ll="ls -l"
alias la="ls -la"
# Mac exclusive
if [[ $(uname -a | cut -f1 -d ' ') == "Darwin" ]]; then
    alias diretide="echo '༼ つ ◕_◕ ༽つ' | pbcopy"
    alias shrug="echo '¯\_(ツ)_/¯' | pbcopy"
    alias nt="open -a Terminal `pwd`"
fi
alias cdhome="cd $OPENED_AT"
alias mvnerr="cat ~/lastbuild.log"
alias ip="ifconfig | grep 'inet ' | grep -Fv 127.0.0.1 | cut -f2 -d ' '"

#functions
mkcd () {
	mkdir -p $1 && cd $1
}

purge() {
	rm -rf $(find . -maxdepth 1 -ctime +20 -type d)
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
	${PathToIntelliJ} ${openDir}
}

# If you ctrl shift click an intellij file it'll get the absolute path. This makes that cd to the base maven dir
function cdWrap() {

    if [ $# -ne 0 ] && [ -f $1 ] && [[ $(echo $1 | egrep "/src/") != "" ]]; then
        cd $(echo $1 | awk -F"/src/" '{print $1}')
    else
        cd $1
    fi

}

mvnhome() {

	OLD_DIR=$(pwd)
	
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

function cdn () {
	cd $(ls -dt */ | head -1)
}

function start() {
    if [ $# -ne 1 ]; then
        echoerr "$0 takes the name of the project to start"
        return $?
    fi

    WORKSPACE=$(cat ~/.jamesrc/.workspaceLocationFile)
    toStart=$(ls -t ${WORKSPACE}../lib/${1}/ | head -1)
    echoinf "Starting ${toStart}"

    ${WORKSPACE}../lib/${1}/${toStart}/bin/${1}

    unset WORKSPACE
}


function run() {
    if [ -f $1 ]; then
        $SHELL $@
    elif [ -f ~/scripts/$1 ]; then
        $SHELL ~/scripts/$@
    else
        echoerr "> $0 $@ :: $1 not found"
    fi
}
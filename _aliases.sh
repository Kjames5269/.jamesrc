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
function maven() {
	mvn $@
}

countChars() {
	if [ $# -lt 2 ]; then
		echoerr "> $0 ',' \"Foo, bar, baz\""
		exit
	fi
	echo ${2} | awk -F"${1}" '{print NF-1}'
}

mkcd () {
	mkdir -p $1 && cd $1
}

purge() {
	rm -rf $(find . -maxdepth 1 -ctime +20 -type d)
}

acDebug() {

    local args=()

    for i in $@; do
        if [[ $i == "-b" ]]; then
            acDebug_background="ON"
            continue
        fi
        args=(${args} $i)
    done

    if [ -z ${acdebugger} ]; then
        test ! -z ${acDebug_background} && echoerr "ACDebugger is not within the workspace"
        unset acDebug_background
        return
    fi

    if [ -z ${acDebug_background} ]; then
        java -jar $(ls ${acdebugger}/debugger/target/*-with-dependencies.jar) ${args[@]}
    else
        java -jar $(ls ${acdebugger}/debugger/target/*-with-dependencies.jar) ${args[@]} &
        acDebugPid=$!
        unset acDebug_background
    fi
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

	# Only open intellij on GIT Roots.
    if git rev-parse --show-toplevel &> /dev/null; then
        openDir=$(cd ${openDir} && git rev-parse --show-toplevel) &> /dev/null
    fi

	${PathToIntelliJ} ${openDir}
}

# If you ctrl shift click an intellij file it'll get the absolute path. This makes that cd to the base maven dir
function cdWrap() {

    if [ $# -ne 0 ] && [ -f $1 ] && [[ $(echo $1 | egrep "/src/") != "" ]]; then
        cd $(echo $1 | awk -F"/src/" '{print $1}')
    elif [[ $1 =~ ^.*\.pom\.xml$ ]]; then
	    cd $(echo $1 | rev | cut -f2- -d '/' | rev)
    else
        cd $1
    fi

}

mvnhome() {

	OLD_DIR=$(pwd)
	
	cd "$OPENED_AT"
	MVNCMD=($(cat ${JRC_DFLT_MAVEN}))
    mvn clean install ${MVNCMD[*]} ${@}

	cd "$OLD_DIR"
}

#Set up global Variables
if [ -f ${JRC_WORKSPACE} ]; then
	WORKSPACE=$(cat ${JRC_WORKSPACE})

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

function cdf () {
	if [ $# -ne 1 ]; then
		return 1
	fi
	# Check if the directory exist and if so just be a cd clone.
	if [ -d $1 ]; then
		cd $1
		return $?
	fi

	# Otherwise act as intended and find the directory in the struct
	# If youve got a larger directory depth than 1000 you got problems
	len=1000
	cdfPath=""
	for i in $(find . -name ${1} -type d | grep -vi "/target/" | cut -f2- -d '/'); do

		temLen=$(countChars '/' "$i")
		if [ ${len} -gt ${temLen} ]; then
			len=${temLen}
			cdfPath="$i"
			cdfOptions=""
		elif [ ${len} -eq ${temLen} ]; then
		    cdfOptions="${cdfOptions}\n$(pwd)/${i}"
		fi
	done
	if [ -z ${cdfPath} ]; then
		return 1
    elif [ ! -z ${cdfOptions} ]; then
        echo -n "Did you mean to CD to: "
        echo -e "${cdfOptions}"
    fi
	cd ${cdfPath}
	unset cdfPath
	unset cdfOptions
}

# Trap
function noOP() {
    local retval=$?
    echo ""
    return ${retval}
}

function start() {
    if [ $# -eq 0 ] || [ $# -gt 2 ]; then
        echoerr "$0 takes the name of the project to start and optionally -n to avoid starting the acDebugger"
        return $?

    elif [ $# -eq 2 ] && [[ $1 == "-n" ]]; then
        noDebug="true"
        shift

    elif [ $# -ne 1 ]; then
        echoerr -e "Invalid parameter \n> $0 '$1' $2"
        return
    fi

    local WORKSPACE=$(cat ${JRC_WORKSPACE})
    local project toStart

    if [[ $1 =~ "^.+-.+$" ]]; then
        project=$(echo $1 | cut -f1 -d '-')
        toStart=$(ls -t ${WORKSPACE}../lib/${project}/ | grep $1 | head -1)
    else
        project=$1
        toStart=$(ls -t ${WORKSPACE}../lib/${project}/ | head -1)
    fi

    if [ -z ${toStart} ]; then
        echoerr "${project} is not a valid project, or your directory structure is busted!"
        unset noDebug
        return
    fi

    if [ -z ${noDebug} ]; then
        # If the log directory doesn't exist yet... create it!
        if [ ! -d ${WORKSPACE}../lib/${project}/${toStart}/data/log/ ]; then
            mkdir -p ${WORKSPACE}../lib/${project}/${toStart}/data/log/
        fi

        echoinf -n "Starting the AC Debugger on Job: "

        acDebug -b -c -r -w &> "${WORKSPACE}../lib/${project}/${toStart}/data/log/acDebugger.log"

        echoinf "Logging to ${project}/${toStart}/data/log/acDebugger.log"
    fi

    echoinf "Starting ${toStart}"

    # If a user enters Ctrl C we will regain control and shutdown the debugger.
    trap noOP 2

    ${WORKSPACE}../lib/${project}/${toStart}/bin/${project}

    # Kill the debugger when it's all said and done
    if [ ! -z ${acDebugPid} ] && ps | egrep "^ *${acDebugPid}" &> /dev/null; then
        echo "------------------------------------------------------------"
        echoinf "Shutting down the acDebugger..."
        kill ${acDebugPid}
        local file="${WORKSPACE}../lib/${project}/${toStart}/data/log/acDebugger.log"
        test -f ${file} && cat ${file}
    fi

	unset acDebugPid noDebug

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

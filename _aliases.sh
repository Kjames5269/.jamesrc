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
    local acDebugFile=""

    for i in $@; do
        if [[ $i == "-b" ]]; then
            acDebug_background="ON"
            continue
        elif [ -d "$(echo $i | rev | cut -f2- -d '/' | rev)" ]; then
            acDebugFile="$i"
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
        ( java -jar $(ls ${acdebugger}/debugger/target/*-with-dependencies.jar) ${args[@]} | tee ${acDebugFile} )
    else
        ( java -jar $(ls ${acdebugger}/debugger/target/*-with-dependencies.jar) ${args[@]} | tee ${acDebugFile} ) &
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
		if isHeroBuildable "${WORKSPACE}${file}"; then
		    temp=$(getMasterBuilder "${WORKSPACE}${file}")
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
    local project toStart projId

    if [[ $1 =~ "^.+-.+$" ]]; then
        project=$(echo $1 | cut -f1 -d '-')
        projId=$(echo $1 | cut -f2- -d '-')
        toStart=$(ls -t ${WORKSPACE}../lib/${project}/ | egrep "${project}.*${projId}" | head -1)
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

        acDebug -b -c -r -w "${WORKSPACE}../lib/${project}/${toStart}/data/log/acDebugger.log"

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
        kill -9 -${acDebugPid}
        local file="${WORKSPACE}../lib/${project}/${toStart}/data/log/acDebugger.log"
        test -f ${file} && echo "acDebug logs can be found here: ${file}"
    fi

    trap - SIGINT
    echo "${acDebugPid}"
	unset acDebugPid noDebug

}

function mvn2() {
    mvn $@ "-s" "/Users/kyle.grady/.m2/repoSettings.xml"
}

# When you always forget shasum
function verify() {

    local sha
    if [[ $1 =~ "^-a$" ]] && [ $# -eq 4 ]; then
        if [ ! -f ${4} ]; then
            echo "$4 does not exist"
            return 1
        fi
        sha=$(shasum $1 $2 $4)
        shift
        shift
    elif [[ $# -eq 2 ]]; then
        if [ ! -f ${2} ]; then
            echo "$2 does not exist"
            return 1
        fi
        sha=$(shasum $2)
    else
        echo "Use shasum or \"$0 -a alg sha filename\""
        return 1
    fi

    diff -bwE <(echo ${sha}) <(echo "$1 $2") &> /dev/null
    if [ $? -eq 0 ]; then
        echo "Valid"
    else
        echo "Invalid: Sha differs"
        return 1
    fi
}

function untar() {
    if [ $# -ne 1 ]; then
        echo "$0 requires the file you wish to untar"
    elif [[ $1 =~ ^.+\.tar\.gz ]]; then
        tar xvfz $1
    elif [[ $1 =~ ^.+\.tar ]]; then
        tar xvf $1
    else
        echo "$1 does not have the tar file endings"
        return 1
    fi
}

function etar() {
    if [[ $1 == "tar.gz" ]] && [ $# -eq 2 ]; then
        if [ ! -d "$2" ]; then
            echo "The directory $2 does not exist"
            return 1
        fi
        tar -czvf "$2.tar.gz" $2
    elif [[ $1 == "tar" ]] && [ $# -eq 2 ]; then
        if [ ! -d "$2" ]; then
            echo "The directory $2 does not exist"
            return 1
        fi
        tar -cvf "$2.tar" $2
    else
        if [ ! -d "$1" ]; then
            echo "The directory $1 does not exist"
            return 1
        fi
        tar -czvf "$1.tar.gz" $1
    fi
}

# register script [as alias]
# Todo :: add unregister command?
function register() {

    local name script reg length args ans

    # Greater than 3 arguments: second to last being "as" and last being the alias
    if [ $# -ge 3 ] && [[ ${@: -2:1} == "as" ]] && [ -f $1 ]; then
        # We want to go 2 space back to not include
        # As and 1 space forward to ignore the name
        length=$(($# - 3))
        name=${@: -1}
        args=${@:2:${length}}
    elif [ $# -ge 1 ] && [ -f $1 ]; then
        # Just ignore the initial name
        length=$(($# - 1))
        if [[ $1 =~ "^\.?[a-z][A-Z][0-9]+\.[a-z]*sh$" ]]; then
            name=$(echo $1 | rev | cut -f2- -d '.' | rev)
        elif [[ $1 =~ "^\.?.+\.[a-z]*sh$" ]]; then
            name=$(echo $1 | rev | cut -f1 -d '/' | cut -f2- -d '.' | rev)
        elif [[ $1 =~ "/" ]]; then
            name=$(echo $1 | rev | cut -f1 -d '/' | rev)
        else
            name=$1
        fi
        args=${@:2:${length}}
    else
        echoerr "> $0 script [cmds] [as alias]"
    fi

    if [[ $1 =~ ^/ ]]; then
        script=$1
    else
        script="$(pwd)/$1"
    fi

    reg=$(egrep "^$name:.+" ${JRC_REGISTERED} 2> /dev/null)

    if [ $? -eq 0 ]; then
        echo -n "${name} is already aliased to ${script} ${args}. Would you like to override? [y/n]: "
        read ans
        if [[ ${ans} != "y" ]]; then
            return 1
        fi
        sed -i '' 's+'"${reg}"'+'"${name}:${script} ${args}"'+' ${JRC_REGISTERED}
    else
        echo "${name}:${script} ${args}"
        echo "${name}:${script} ${args}" >> ${JRC_REGISTERED}
    fi

    alias ${name}="${script} ${args}"
}

if [ -f ${JRC_REGISTERED} ]; then
    while read -r line; do
        jrc_register_ali=$(echo ${line} | cut -f1 -d ':')
        jrc_register_scr=$(echo ${line} | cut -f2 -d ':')
        alias ${jrc_register_ali}="${jrc_register_scr}"
    done < "${JRC_REGISTERED}"
    unset jrc_register_ali jrc_register_scr line
fi

function mod() {
    retVal=$1
    while [ ${retVal} -gt $2 ]; do
        retVal=$((retVal-$2))
    done
}

function rainbowEcho() {
tput sc
while [ $# -eq 1 ]; do
    for i in $(seq 1 15); do
        tput rc
        for j in $(seq 0 "${#1}"); do
            mod $((i+j)) "15"
            printf "\033[38;5;${retVal}m${1:$j:1}\033[0m"
        done
        sleep .15
    done
done
}
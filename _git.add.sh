#!/usr/bin/env zsh

function preaddHook() {
     if ! [ -f "${GIT_HOME}/pom.xml" ] || [ $# -eq 1 ]; then
        return 0
     fi

     checkMvnValidate $@

     unset listOfChanged
     unset mavenFmtDirName
     unset mavenFmtDirErrors
}

function checkMvnValidate() {

    if [ -e $2 ]; then
        # This isn't perfect but it should be "good enough"
        listOfChanged=($(${whichGit} ls-files -m  | grep /src/ | grep $2 | awk -F"/src/" '{print $1}' | uniq))
    elif [ $# -eq 2 ]; then
        #listOfChanged=($(${whichGit} status --short | grep /src/ | awk -F"/src/" '{print $1}' | cut -c4- | uniq))
        listOfChanged=($(${whichGit} ls-files -m | grep /src/ | awk -F"/src/" '{print $1}' | uniq))
    else
        echoerr "This is not yet implemented. Add one file at a time"
        return $?
    fi

    mavenFmtDirName="${GIT_HOME}/.git/_GIT_MAVEN_FORMATTING/"
    mavenFmtDirErrors="${GIT_HOME}/.git/_GIT_MAVEN_FORMATTING_ERRORS/"

    if [ -d ${mavenFmtDirErrors} ]; then
        rm -rf ${mavenFmtDirErrors}
    fi

    if [ ${#listOfChanged[@]} -gt 0 ]; then

        mkdir ${mavenFmtDirName}
        mkdir ${mavenFmtDirErrors}

        for i in ${listOfChanged[@]}; do
            ( mvnFmt ${GIT_HOME}/${i} & )
        done

        # R A C E  C O N D I T I O N S
        # This is unfortunately done because I want quiet terminals
        # that are not cluttered with PID's of background processes
        # This however means that there is no way to wait for the child
        # since the child is technically done... So this was the alternative
        sleep 1

        for i in $(alias | grep "ferr[0-9]*=" | cut -f1 -d '='); do
            unalias ${i}
        done

        counter=0
        counter2=16

        while [ $(/bin/ls ${mavenFmtDirName} | wc -l) -ne 0 ]; do
            sleep .25
            counter=$(($counter+1))
            if [ ${counter} -eq ${counter2} ]; then
                counter=0
                if [ ${counter2} -gt 1 ]; then
                    counter2=$((${counter2}-1))
                fi
                echo -n ".  "
            fi
        done

        echo ""
        unset counter

        rm -d ${mavenFmtDirName}

        if [ $(/bin/ls ${mavenFmtDirErrors} | wc -l) -ne 0 ]; then
            echoerr "One or more formatting errors occurred. Nothing was added"
            echoerr "Errors can be found here: ${mavenFmtDirErrors}"
            echoerr "Or running: $ ferr{Number}"

            for i in $(/bin/ls ${mavenFmtDirErrors}); do
                alias ferr${i}="cat ${mavenFmtDirErrors}/${i}"
            done
            return $?
        fi

        rm -d ${mavenFmtDirErrors}
    fi

}
function mvnFmt() {
    if ! [ -d $1 ]; then
        return 0
    fi

    myPid=${sysparams[pid]}

    mkdir ${mavenFmtDirName}${myPid}

    echoinf "mvn validate: $1"

    cd $1
    
    # Format first to catch small errors then go in for the validator
    mvn fmt:format &> /dev/null
    mvn validate &> ${mavenFmtDirErrors}${myPid}

    if [ $? -ne 0 ]; then
        echoerr "[ "${myPid}" ] $ mvn validate $1"
    else
        rm ${mavenFmtDirErrors}${myPid}
    fi

    rm -d ${mavenFmtDirName}${myPid}

    unset myPid
}

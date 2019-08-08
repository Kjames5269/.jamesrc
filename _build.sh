#!/bin/sh

changePorts="run changePorts.sh 0 $(ls -t | head -1)"

#ZSH STARTS ARRAYS AT 1 Ahhhhh
heroBuild() {
    HERO_BUILD=$1 build ${@:2}
}

build () {

    andClean() {
        if isHeroBuildable "${WORKSPACE}.." && ! [ -z ${buildMaven} ]; then
        	removeFromBuildConf "${WORKSPACE}.." ${buildMaven}
        fi
        unset buildMavenCmd buildMaven back
        unset mvnToRun fdir nonZipDir
        unset LATEST MVNCMD
        unset FROM_PATH TO_PATH

        return $1
    }

	fdir=$(pwd)

	#function call
	setupWorkspace
	if [ $? -eq 1 ]; then
		return 1
	fi

	WORKSPACE=$(cat ${JRC_WORKSPACE})

	MVNCMD=($(cat ${JRC_DFLT_MAVEN}))

	if [ $# -eq 0 ]; then
		echoerr "Specify a valid project: build ddf"
		return 1
	fi

	#Arguments

	local OFF=0
	local ON=1

	local RESET=$ON
	local LS=$OFF
	local REDIRECTION="${HOME}/lastbuild.log"
	local ERROR_REDIRECT="/dev/stdout"
	local START=$OFF
	local BRANCH=""
	local LATEST=$OFF
	local NULLS=$OFF
	local localHOST=$OFF

	local THREADS=8
	local LIB="lib/"

	local FOUND=0

	while [[ $1 =~ ^-.*$ ]]; do
		
		case $1 in
		    "--reset")
			    rm ${JRC_WORKSPACE}
			    rm ${JRC_DFLT_MAVEN}
			    echoinf "Saved data reset"
			    return 0
			    ;;
            "--reset-maven")
			    rm ${JRC_DFLT_MAVEN}
			    echoinf "Maven Defaults reset"
			    return 0
			    ;;
            "--reset-path")
                rm ${JRC_WORKSPACE}
                echoinf "Directory path defaults reset"
			    return 0
			    ;;
            "--ls")
			    LS=$ON
                shift
                continue
                ;;
			# Help commands are useful
		    "--help")
			echo "This script is intented to build any project with the ddf alliance setup with the current branch appended"
			echo -e "Mvn Defaults: $(cat ${JRC_DFLT_MAVEN})\nDirectory Path: $(cat ${JRC_WORKSPACE})"
			echo -e "Supported args:\n\t-s to skip the build and unzip a new distro\n\t--reset to delete saved data \n\t\t--reset-maven\n\t\t--reset-path)"
			echo -e "\t-m override using default maven commands (Can't override clean install)\n\t-v verbose to print maven"
			echo -e "\t-n pipe maven output to /dev/null\n\t--ls to show directories in your saved directory\n\t-[number] change the thread count"
			echo -e "\t-b to boot after build (only works for ddf alliance)"
			echo -e "\t--branch=branchName sets the branch to the given branch instead of the current (stashes changes)"
			echo -e "\t-p runs git fetch --all; git pull -r. Pray for no merge conflicts"
			echo -e "\t-l runs on localhost" 
			echo -e "\nAfter the build name you can add additional maven arguments"
			echo -e " > build -bm -v ddf [maven commands]"
			echo -e "\nIf there are any comments or concerns send them here: kyle.grady@connexta.com"
			return 0

		esac

		if [[ $1 =~ ^--branch=.+$ ]]; then
			BRANCH="$(echo $1 | cut -f2- -d '=')"

			shift
			continue
		fi

		arglen=$(echo ${#1})
		
		for (( i=1; i<${#1}; i++ )); do

			ARGS=$(echo "${1:$i:1}")
			len=$(( $arglen - $i ))

			# Force a maven build (Even if there is one snapshotted)
			case $ARGS in
			    "s")
				    RESET=$OFF
                    ;;
                "b")
				    START=$ON
				    ;;
                "m")
                    MVNCMD=("")
                    ;;
                "v")
                    REDIRECTION="/dev/stdout"
                    # Maven gives all the errors this would
                    ERROR_REDIRECT="/dev/null"
                    ;;
                "p")
                    LATEST=$ON
                    ;;
                "n")
                    REDIRECTION="/dev/null"
                    NULLS=$ON
                    ;;
		"l")
		    localHOST=$ON
		    ;;
                *)
                    if [[ $(echo "${1:$i:$len}") =~ ^[0-9]*$ ]]; then
                        THREADS=$(echo "${1:$i:$len}")
                    else
                    	echoerr "$ARGS is not a valid argument"
                        return 1
                    fi
            esac
		
		#End of For loop for parsing characters
		done
	
		shift

	#End of while loop parsing args
	done

	if [ $LS -eq $ON ]; then
		ls ${WORKSPACE}
		return $?
	fi

	if [ ! -d $WORKSPACE/$1 ]; then
		echoerr "The workspace $WORKSPACE/$1 invalid"
		return 1
	fi

	unset buildMaven
	#Done parsing args
	if isHeroBuildable "${WORKSPACE}${1}"; then

        if [ -z ${HERO_BUILD} ]; then
            masterName=$(getMasterBuilder "${WORKSPACE}${1}")

            # Check if there is already a build running...
            if isCurrentlyBuilding "${WORKSPACE}${1}" ${masterName}; then
                echoerr "$1 is already building. If you believe this to be an error run"
                echoerr "> removeFromBuildConf "${WORKSPACE}${1}" ${masterName}"
                return $(andClean 1)
            fi

            buildMaven="${masterName}"

	    else
            local hero_space=" "
	    	buildMaven=$(getHeroRepo ${WORKSPACE}${1})
	    	if [ -z ${buildMaven} ]; then
	    	    echoerr "There are no available hero slots"
	    	    echoerr "Current Builds(): " $(getRunningBuilds ${WORKSPACE}${1})
	    	    return $(andClean 1)
	    	fi

        fi

        addToBuildConf "${WORKSPACE}${1}" ${buildMaven}
        WORKSPACE="${WORKSPACE}${1}/${buildMaven}/"
	    buildMavenCmd=("-s" "/Users/kyle.grady/.m2/${buildMaven}Settings.xml")
	    back="../../../"

    else
        WORKSPACE=${WORKSPACE}${1}/
        back="../../"
    fi


	# Path confirmed and workspace found

	FROM_PATH="${WORKSPACE}distribution/$1/target/"
	TO_PATH="${WORKSPACE}${back}${LIB}$1/"

	# Get the current git branch
	fetched=$OFF

	cd ${WORKSPACE}
	# Even if it's a hero build. Dont' bother with git if reset is off.
	if [ ! -z ${HERO_BUILD} ] && [ ${RESET} -eq ${ON} ]; then
	    if [[ ! -d ".git" ]]; then
	        echoerr "This only works with git repos"
	        return $(andClean 1)
	    fi
	    echoinf "Hero building. Aggressively dealing with git"
        local heroee=$(echo ${HERO_BUILD} | cut -f1 -d ':')
        BRANCH=$(echo ${HERO_BUILD} | cut -f2 -d ':')

        # Reusing logic from the git-wrapper
        git remote add ${heroee} &> /dev/null

        # If the branch exist delete it.
        local branch=$(git rev-parse --verify --quiet ${BRANCH} | head -1)
        if [ ! -z ${branch} ]; then
            # checkout the commit the branch is on, then delete the local branch.
            git checkout ${branch} &> /dev/null
            git branch -D ${BRANCH}
        fi

        # fetch all the changes from the hero'ee
        git fetch ${heroee} &> /dev/null

        # Reusing logic from the git-wrapper
        git checkout ${HERO_BUILD}

        BRANCH="-${BRANCH}"

	elif [ -z $BRANCH ] && [[ -d ".git" ]]; then
		BRANCH=$(git branch | grep '\*' | cut -f2 -d '*' | tr ' ' '-')	
	elif [[ -d .git ]]; then
		fetched=$ON
		git fetch --all
		git checkout $BRANCH
		
		if [ $? -ne 0 ]; then
			echoerr "$BRANCH does not exist within $WORKSPACE"
			return $(andClean 1)
		fi

		BRANCH="-${BRANCH}"
	fi

	if [ $LATEST -eq $ON ] && [ ${RESET} -eq ${ON} ] ; then
		if [ $fetched -eq $OFF ] ;then
		    if ! git diff-index --quiet HEAD --; then
		        echoinf "Stashing changes on -${BRANCH}"
		        git stash
		    fi
			git fetch --all
		fi
		# We pray for no merge conflicts
		git pull -r
		if [ $? -ne 0 ]; then
		    echoinf "Merge Conflicts! stopping..."
		    return $(andClean 1)
		fi
	fi

	# Get the Zip file from the target location
	projname=$(ls ${FROM_PATH}*.zip) &> /dev/null

	# If it doesn't exist then run maven
	if [ $? -ne 0 ] || [ $RESET -eq $ON ]; then
		
		cd ${WORKSPACE}

		echoinf "Maven Building${hero_space}${HERO_BUILD}... "

        mvn -T ${THREADS} clean install ${MVNCMD[*]} ${buildMavenCmd} ${@:2} &> "${REDIRECTION}"

		if [ $? -ne 0 ]; then
		    if [ $NULLS -eq $OFF ]; then
		        echoerr "Build failed! see log file at ${REDIRECTION} for more details" &> "${ERROR_REDIRECT}"
                tail -15 ${REDIRECTION} &> "${ERROR_REDIRECT}"
		    else
		        echoerr "Build Failed" &> "${ERROR_REDIRECT}"
		    fi

			#echoinf "Deleting node* directories"
			#find . -name "node*" -type d | xargs rm -rf

			return $(andClean 1)
		fi

		echo "\033[0;32mBUILD SUCCESS\033[0m" > "${ERROR_REDIRECT}"

	fi	
	        
	# Get the Zip file from the target location
        projname=$(ls ${FROM_PATH}*.zip) &> /dev/null

	if [ $? -ne 0 ]; then
		#Not a ddf build
		return $(andClean 1)
	fi

	if [ ! -d $TO_PATH ]; then
		echoinf "Creating directory $TO_PATH"
		mkdir -p "$TO_PATH"
	fi

	projname=$(ls ${FROM_PATH}*.zip | rev | cut -f1 -d '/' | rev)
	
	mv "${FROM_PATH}${projname}" "$TO_PATH"
	
	cd ${TO_PATH}

	nonZipDir=$(echo $projname | rev | cut -f2- -d '.' | rev)

	if [ -d "${TO_PATH}${nonZipDir}${BRANCH}" ]; then
		echoinf "Deleting old ${nonZipDir}${BRANCH}"
		rm -rf "${TO_PATH}${nonZipDir}${BRANCH}"
	fi

	echoinf "Unzipping $projname..."
	
	unzip "${TO_PATH}${projname}" > /dev/null

	mv "${TO_PATH}${projname}" "$FROM_PATH"
	touch "${nonZipDir}"

	if [ ${localHOST} -eq ${OFF} ] && which changePorts &>/dev/null; then
		changePorts 0 "${nonZipDir}"
	fi

	if [[ ! -z $BRANCH ]]; then
	    echoinf "Renaming to ${nonZipDir}${BRANCH}"
		mv "${nonZipDir}" "${nonZipDir}${BRANCH}"
		cd "${nonZipDir}${BRANCH}/bin"
	else
		cd "${nonZipDir}/bin"
	fi

	if [ $START -eq $ON ]; then
	    # Run Start instead as it should suffice.
		start $1
	fi

	alias hero="${TO_PATH}${nonZipDir}${BRANCH}/bin/$1"

	cd $fdir

	return $(andClean 0)
}

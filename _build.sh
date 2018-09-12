#!/usr/bin/env bash
build () {

    andClean() {
        if [ -f ${WORKSPACE}../${CONFIG} ]; then
        	building=$(grep "building=" ${WORKSPACE}../${CONFIG} | cut -f2 -d '=')
	        buildingNo=$(($building-1))
	        sed -i '' 's/building=./building='${buildingNo}'/' ${WORKSPACE}../${CONFIG}
        fi
        unset building
        unset buildingNo
        unset buildMavenCmd
        unset buildMaven
        unset back
        unset REDIRECTION
        unset ERROR_REDIRECT
        unset mvnToRun
        unset fdir
        unset nonZipDir
        unset BRANCH
        unset ON
        unset OFF
        unset CONFIG
        unset LATEST
        unset THREADS
        unset LIB
        unset MVNCMD
        unset FROM_PATH
        unset TO_PATH

        return $1
    }

    CONFIG="build.config"

	fdir=$(pwd)

	#function call
	setupWorkspace
	if [ $? -eq 1 ]; then
		return 1
	fi

	WORKSPACE=$(cat ~/.jamesrc/.workspaceLocationFile)

	MVNCMD=($(cat ~/.jamesrc/.workspaceDefaultMaven))

	if [ $# -eq 0 ]; then
		echoerr "Specify a valid project: build ddf"
		return 1
	fi

	#Arguments

	OFF=0
	ON=1

	RESET=$ON
	LS=$OFF
	REDIRECTION="${HOME}/lastbuild.log"
	ERROR_REDIRECT="/dev/stdout"
	START=$OFF
	BRANCH=""
	LATEST=$OFF
	NULLS=$OFF

	THREADS=8
	LIB="lib/"

	FOUND=0

	while [[ $1 =~ ^-.*$ ]]; do
		
		case $1 in
		    "--reset")
			    rm ~/.jamesrc/.workspaceLocationFile
			    rm ~/.jamesrc/.workspaceDefaultMaven
			    echoinf "Saved data reset"
			    return 0
			    ;;
            "--reset-maven")
			    rm ~/.jamesrc/.workspaceDefaultMaven
			    echoinf "Maven Defaults reset"
			    return 0
			    ;;
            "--reset-path")
                rm ~/.jamesrc/.workspaceLocationFile
                echoinf "Directory path defaults reset"
			    return 0
			    ;;
            "-ls")
			    LS=$ON
                shift
                continue
                ;;
			# Help commands are useful
		    "--help")
			echo "This script is intented to build any project with the ddf alliance setup with the current branch appended"
			echo -e "Mvn Defaults: $(cat ~/.jamesrc/.workspaceDefaultMaven)\nDirectory Path: $(cat ~/.jamesrc/.workspaceLocationFile)"
			echo -e "Supported args:\n\t-s to skip the build and unzip a new distro\n\t--reset to delete saved data \n\t\t--reset-maven\n\t\t--reset-path)"
			echo -e "\t-m override using default maven commands (Can't override clean install)\n\t-v verbose to print maven"
			echo -e "\t-n pipe maven output to /dev/null\n\t-ls to show directories in your saved directory\n\t-[number] change the thread count"
			echo -e "\t-b to boot after build (only works for ddf alliance)"
			echo -e "\t--branch=branchName sets the branch to the given branch instead of the current (stashes changes)"
			echo -e "\t-l runs git fetch --all; git pull -r. Pray for no merge conflicts"
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
                "l")
                    LATEST=$ON
                    ;;
                "n")
                    REDIRECTION="/dev/null"
                    NULLS=$ON
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
		echoerr "The workspace $WORKSPACE$1 invalid"
		return 1
	fi

	unset buildMaven
	#Done parsing args
	if [ -f ${WORKSPACE}${1}/${CONFIG} ]; then

        masterName=$(grep "master=" ${WORKSPACE}${1}/${CONFIG} | cut -f2 -d '=')
	    building=$(grep "building=" ${WORKSPACE}${1}/${CONFIG} | cut -f2 -d '=')

	    if [ ${building} -eq 1 ]; then
	        buildMaven="${masterName}"
	        WORKSPACE="${WORKSPACE}${1}/${buildMaven}/"
	    elif [ ${building} -eq 0 ]; then
	    	buildMaven=$(ls -d ${WORKSPACE}${1}/*/ | grep -v "${masterName}$" | head -1 | rev | cut -f2 -d '/' | rev)
	        WORKSPACE="${WORKSPACE}${1}/${buildMaven}/"
	        heroBuild=1
	    else
	        echoerr "Too many builds for now... (who needs to build 3 things anyway??)"
	        return $?
	    fi
	    buildingNo=$(($building+1))
	    sed -i '' 's/building=./building='${buildingNo}'/' ${WORKSPACE}../${CONFIG}
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
	if [ -z $BRANCH ] && [[ -d ".git" ]]; then
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

	if [ $LATEST -eq $ON ]; then
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

		echoinf "Maven Building..."

        mvn -T ${THREADS} clean install ${MVNCMD[*]} ${buildMavenCmd} ${@:2} > "${REDIRECTION}"

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

	if [[ ! -z $BRANCH ]]; then
	    echoinf "Renaming to ${nonZipDir}${BRANCH}"
		mv "${nonZipDir}" "${nonZipDir}${BRANCH}"
		cd "${nonZipDir}${BRANCH}/bin"
	else
		cd "${nonZipDir}/bin"
	fi

	if [ $START -eq $ON ]; then
		bash $1
	fi

	alias hero="${TO_PATH}${nonZipDir}${BRANCH}/bin/$1"

	cd $fdir

	return $(andClean 0)
}

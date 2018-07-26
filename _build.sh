#!/usr/bin/env bash
build () {

	fdir=$(pwd)

	#function call
	createFiles

	WORKSPACE=$(cat ~/.jamesrc/.workspaceLocationFile)

	MVNCMD=($(cat ~/.jamesrc/.workspaceDefaultMaven))
	
	fileChecks
	
	if [ $? -eq 1 ]; then
		return 1
	fi

	if [ $# -eq 0 ]; then
		echoerr "Specify a valid project: build ddf"
		return 1
	fi

	#Arguments

	OFF=0
	ON=1

	RESET=$ON
	LS=$OFF
	VERBOSE=$OFF	
	START=$OFF
	BRANCH=""
	LATEST=$OFF

	THREADS=8
	LIB="lib/"

	FOUND=0

	while [[ $1 =~ ^-.*$ ]]; do
		
		# Remove Saved Data
		if [[ $1 == "--reset" ]]; then
			rm ~/.jamesrc/.workspaceLocationFile
			rm ~/.jamesrc/.workspaceDefaultMaven
			echoinf "Saved data reset"
			return 0
		fi
		
		if [[ $1 == "--reset-maven" ]]; then
			rm ~/.jamesrc/.workspaceDefaultMaven
			echoinf "Maven Defaults reset"
			return 0
		fi
		
		if [[ $1 == "--reset-path" ]]; then
			rm ~/.jamesrc/.workspaceLocationFile
			echoinf "Directory path defaults reset"
			return 0
		fi

		if [[ $1 == "-ls" ]]; then
			LS=$ON

			shift
			continue
		fi
	
		if [[ $1 =~ ^--branch=.+$ ]]; then
			BRANCH="$(echo $1 | cut -f2- -d '=')"

			shift
			continue
		fi
	
		# Help commands are useful
		if [[ $1 == "--help" ]]; then
			echo "This script is intented to build any project with the ddf alliance setup with the current branch appended"
			echo -e "Mvn Defaults: $(cat ~/.jamesrc/.workspaceDefaultMaven)\nDirectory Path: $(cat ~/.jamesrc/.workspaceLocationFile)"
			echo -e "Supported args:\n\t-s to skip build if one exist\n\t--reset to delete saved data \n\t\t--reset-maven\n\t\t--reset-path)"
			echo -e "\t-m override using default maven commands (Can't override clean install)\n\t"
			echo -e "\t-v verbose to print maven\n\t-ls to show directories in your saved directory\n\t-[number] change the thread count"
			echo -e "\t-b to boot after build (only works for ddf alliance)"
			echo -e "\t--branch=branchName sets the branch to the given branch instead of the current (stashes changes)"
			echo -e "\t-l runs git fetch --all; git pull -r. Pray for no merge conflicts"
			echo -e "\nAfter the build name you can add additional maven arguements"
			echo -e " > build -f -m -p /projects/src/ ddf [maven commands]"
			echo -e "\nIf there are any comments or concerns send them here: kyle.grady@connexta.com" 
			return 0
		fi

		FOUND=0	

		arglen=$(echo ${#1})
		
		for (( i=1; i<${#1}; i++ )); do

			ARGS=$(echo "${1:$i:1}")
			len=$(( $arglen - $i ))

			# Force a maven build (Even if there is one snapshotted)	
			if [[ $ARGS == "s" ]]; then
				RESET=$OFF
				FOUND=1
			fi
	
				
			if [[ $ARGS == "b" ]]; then
				START=$ON
				FOUND=1
			fi
	
			# Unset mvncmd variable
			if [[ $ARGS == "m" ]]; then
				MVNCMD=("")
				FOUND=1
			fi
	
			if [[ $ARGS == "v" ]]; then
				FOUND=1
				VERBOSE=$ON
			fi

			if [[ $ARGS == "l" ]]; then
				FOUND=1
				LATEST=$ON
			fi

			if [[ $(echo "${1:$i:$len}") =~ ^[0-9]*$ ]]; then
				FOUND=1
				THREADS=$(echo "${1:$i:$len}")
				
				break
			fi
	
	
			if [ $FOUND -eq 0 ]; then
				echoerr "$1 is not a valid argument"
				return 1
			fi

		
		#End of For loop for parsing characters
		done
	
		shift

	#End of while loop parsing args
	done
	
	#Done parsing args

	if [ $LS -eq $ON ]; then
		ls $WORKSPACE
		return $?
	fi

	if [ ! -d $WORKSPACE/$1 ]; then
		echoerr "The workspace $WORKSPACE$1 invalid"
		return 1
	fi

	# Path confirmed and workspace found

	FROM_PATH="${WORKSPACE}$1/distribution/$1/target/"
	TO_PATH="${WORKSPACE}../${LIB}$1/"

	# Get the current git branch
	fetched=$OFF

	cd ${WORKSPACE}$1
	if [ -z $BRANCH ] && [[ -d ".git" ]]; then
		BRANCH=$(git branch | grep '\*' | cut -f2 -d '*' | tr ' ' '-')	
	elif [[ -d .git ]]; then
		fetched=$ON
		git fetch --all
		git checkout $BRANCH
		
		if [ $? -ne 0 ]; then
			echoerr "$BRANCH does not exist within $WORKSPACE$1"
			return 1
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
		    return 1
		fi
	fi

	# Get the Zip file from the target location
	projname=$(ls ${FROM_PATH}*.zip) &> /dev/null

	# If it doesn't exist then run maven
	if [ $? -ne 0 ] || [ $RESET -eq $ON ]; then
		
		cd ${WORKSPACE}$1

		echoinf "Maven Building..."

		# IF verbose is on then output to console not log
		if [ $VERBOSE -eq $ON ]; then
			mvn -T ${THREADS} clean install ${MVNCMD[*]} ${@:2}
		else
			mvn -T ${THREADS} clean install ${MVNCMD[*]} ${@:2} &> ~/lastbuild.log
		fi

		if [ $? -ne 0 ]; then
			if [ $VERBOSE -eq $OFF ]; then
				echoerr "Build failed see log file at ~/lastbuild.log for more details"
				tail -15 ~/lastbuild.log
			fi

			#echoinf "Deleting node* directories"
			#find . -name "node*" -type d | xargs rm -rf

			return 1
		fi

        if [ $VERBOSE -eq $OFF ]; then
		    echo "\033[0;32mBUILD SUCCESS\033[0m"
		fi

	fi	
	        
	# Get the Zip file from the target location
        projname=$(ls ${FROM_PATH}*.zip) &> /dev/null

	if [ $? -ne 0 ]; then
		#Not a ddf build
		return 0
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

	return 0
}


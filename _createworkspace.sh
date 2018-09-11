#!/usr/bin/env bash
createFiles() {

	#Set up the original file
	if [ ! -f ~/.jamesrc/.workspaceLocationFile ]; then
		echo -n -e "Input the path to your workspace containing ddf, alliance and other projects\n"
		echo -e -n " > "
		read input
		
		if ! [[ $input =~ ^.*/$ ]]; then
			input=$input/
		fi

		echo $input > ~/.jamesrc/.workspaceLocationFile
		echoinf "creating ~/.jamesrc/.workspaceLocationFile with $input..."
	fi

	if [ ! -f ~/.jamesrc/.workspaceDefaultMaven ]; then
        echo -n -e "Input default Maven commands\n > mvn -T 8 clean install "
        read input

        echo $input > ~/.jamesrc/.workspaceDefaultMaven
        echoinf "creating ~/.jamesrc/.workspaceDefaultMaven with $input..."
    fi
}

fileChecks() {

	if [ ! -d $(cat ~/.jamesrc/.workspaceLocationFile) ]; then
		
		echoerr "Invalid workspace $(cat ~/.jamesrc/.workspaceLocationFile) does not exist!"
		rm ~/.jamesrc/.workspaceLocationFile
		return 1
	fi

	if [[ $(grep "/src/" ~/.jamesrc/.workspaceLocationFile) != "" ]]; then
		echoerr "You're gonna have a bad time"
		rm ~/.jamesrc/.workspaceLocationFile
		return 1
	fi
	
	return 0
}

setupWorkspace() {
    createFiles
    fileChecks
}
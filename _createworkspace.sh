#!/bin/sh
createFiles() {

	#Set up the original file
	if [ ! -f ${JRC_WORKSPACE} ]; then
		echo -n -e "Input the path to your workspace containing ddf, alliance and other projects\n"
		echo -e -n " > "
		read input
		
		if ! [[ $input =~ ^.*/$ ]]; then
			input=$input/
		fi

		echo $input > ${JRC_WORKSPACE}
		echoinf "creating ${JRC_WORKSPACE} with $input..."
	fi

	if [ ! -f ${JRC_DFLT_MAVEN} ]; then
        echo -n -e "Input default Maven commands\n > mvn -T 8 clean install "
        read input

        echo $input > ${JRC_DFLT_MAVEN}
        echoinf "creating ${JRC_DFLT_MAVEN} with $input..."
    fi
}

fileChecks() {

	if [ ! -d $(cat ${JRC_WORKSPACE}) ]; then
		
		echoerr "Invalid workspace $(cat ${JRC_WORKSPACE}) does not exist!"
		rm ${JRC_WORKSPACE}
		return 1
	fi

	if [[ $(grep "/src/" ${JRC_WORKSPACE}) != "" ]]; then
		echoerr "You're gonna have a bad time"
		rm ${JRC_WORKSPACE}
		return 1
	fi
	
	return 0
}

setupWorkspace() {
    createFiles
    fileChecks
}
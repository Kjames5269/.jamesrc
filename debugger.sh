#!/bin/sh

PATH_TO_DEBUGGER="/projects/isrc/acdebugger"
LOG_DIR=""

function noOP() {
	local retval=$?
	echo ""
	return ${retval}
}

if [ $# -eq 0 ]; then
    echo "$0 takes the script to start as well as other arguments to it."
    exit 1
fi

pathToScript=$1

#normalize the path
if [[ $1 =~ /$ ]]; then
    pathToScript=${pathToScript::-1}
fi

binDir=$(echo ${pathToScript} | rev | cut -f2- -d '/' | rev)

if [ -z ${LOG_DIR} ]; then
    baseDir="${binDir}/.."
    LOG_DIR="${baseDir}/data/log"
fi

# If the log directory doesn't exist yet... create it!
if [ ! -d ${LOG_DIR} ]; then
    mkdir -p ${LOG_DIR}
fi

# make the logDir resolve paths
LOG_DIR=$(cd ${LOG_DIR} && pwd)

theDebugger=$(find ${PATH_TO_DEBUGGER}/debugger/target -name "acdebugger-debugger-*-jar-with-dependencies.jar")

java -jar ${theDebugger} -c -r -w &> "${LOG_DIR}/acDebugger.log" &

acDebugPid=$!

echo "Starting the AC Debugger with PID: ${acDebugPid} "

echo "Logging to ${LOG_DIR}/acDebugger.log"

echo "Starting ${1}"

# If a user enters Ctrl C we will regain control and shutdown the debugger.
trap noOP 2

#Start the argument
$@

# Kill the debugger when it's all said and done
if ps | egrep "^${acDebugPid}" &> /dev/null; then
    echo "------------------------------------------------------------"
    echo "Shutting down the acDebugger..."
    kill ${acDebugPid}
    file="${LOG_DIR}/acDebugger.log"
    test -f ${file} && cat ${file}
fi
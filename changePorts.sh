#!/bin.sh

MAX_PORT=65535
MIN_PORT=1000
DFLT_HOST="localhost"
DFLT_JUMP=2000

# 
#  What files should be allowed to be changed. 
#  -- This is here mainly because the regex picks up every port, even those that are edited elsewhere in xml's / shouldn't be changed
#
toChange=("users.attributes" "users.properties" "system.properties" "custom.system.properties" "org.apache.karaf.shell.cfg" "org.apache.karaf.management.cfg")

#
#  What ports should be printed at the end of execution?
#  --  Aka the important ones, like https://localhost:8993
#
isImportant=("org.codice.ddf.system.httpsPort" "solr.http.port")

function isChangeable() {
	fileName=${1##*/}
	for j in ${toChange[@]}; do
		if [[ $fileName == $j ]]; then
			return 0
		fi
	done
	return 1
}

# Checks if the ports are in bounds and corrects them
function portCheck() {
        # This tries to correct small mistakes but does not replace incompetence
        if [[ ${newPort} -gt ${MAX_PORT} ]]; then
                newPort=$((${newPort}-${MAX_PORT}+${MIN_PORT}))
        elif [[ ${newPort} -le ${MIN_PORT} ]]; then
                newPort=$((${newPort}+${MAX_PORT}-${MIN_PORT}))
        fi
}

loud=0
SAFE=0
bm=""

while [ $# -ne 0 ]; do
	if [ -d $1 ] && [ -z ${project} ]; then
		project=$1
	elif [[ $1 =~ ^[0-9]+$ ]] && [ -z ${port} ]; then
		port=$1
	elif [[ $1 =~ ^-l+$ ]]; then
		loud=$((${loud} + ${#1} -1))
	elif [[ $1 == "--help" ]]; then
		echo "$0 takes 1 argument and a couple optional arguments"
		echo "\t+ an existing directory to have the ports changed"
		echo "\t- A number to add to the ports (defaults ${DFLT_JUMP})"
		echo "\t- -l to be loud / verbose"
		echo "\t- --safe to only choose ports that are currently unused.\n\t\t-- It's really slow so keep that in mind"
		echo "\t- A argument that doesn't match those to be used as a hostname (default is $(hostname))"
		echo "\t\t- oldHostname:newHostname will change the oldHostname to the new one. This is by default ${DFLT_HOST}"
		echo "> $0 ddf 23 ecp1"
		echo "> $0 23 ecp1:ecp2 ddf -l"
		exit 1
	elif [[ $1 == "--safe" ]];then
		SAFE=1
	elif [[ ! $1 =~ ^- ]] && [ -z ${hostname} ] && [ -z ${oldHostname} ]; then
		if [[ $1 =~ ^.*:.*$ ]]; then
			oldHostname=$(echo "$1" | cut -f1 -d ':')
			hostname=$(echo "$1" | cut -f2 -d ':')
		else
			hostname=$1
		fi
	else
		echo "Invalid arguments try --help"
		echo "at > $0$bm '$1' ${@:2}" 
		exit 1
	fi

	bm="${bm} ${1}"
	shift
done

test -z ${project} && echo "enter in a valid filename" && exit 1
test -z ${port} && port=${DFLT_JUMP}
test -z ${hostname} && hostname=$(hostname)
test -z ${oldHostname} && oldHostname=${DFLT_HOST}

oldIFS=${IFS}
IFS='
'

if [ ${loud} -gt 2 ]; then
	echo "PROJECT: ${project}\nPORT: ${port}\nHOSTNAME: ${hostname}\nLOUDNESS: ${loud}\noldHostname: ${oldHostname}\n---"
fi

test ${loud} -gt 0 && echo "Updating ports...\n"

# Matches all ports = numbers. Gets all the files in projects/etc
for i in $(egrep "(p|P)ort\s*=(\s|[0-9])+$" $(find ${project}/etc -maxdepth 1 -type f)); do

	test ${loud} -gt 2 && echo ${i}

	# parsing grep output
	filePath=$(echo ${i} | cut -f1 -d ':')

	isChangeable ${filePath}
	if [[ $? -eq 1 ]]; then
		test ${loud} -gt 1 && echo "${filePath} is not in the list of changeable files:\n${toChange[@]}\n---"
		continue
	fi

	beforeRepl=$(echo ${i} | cut -f2 -d ':')
	name=$(echo ${beforeRepl} | cut -f1 -d '=')
	portNo=$(echo ${beforeRepl} | cut -f2 -d '=')
	newPort=$((${portNo}+${port}))

	portCheck

	if [ ${SAFE} -eq 1 ]; then
		echo "Checking to see if ${newPort} is in use..."
		lsof | grep LISTEN | grep ":${newPort}"
		while [ $? -eq 0 ]; do
			newPort=$(($newPort+1))
			portCheck
			lsof | grep LISTEN | grep ":${newPort}"
		done
	fi

	# try to keep the formatting. (for us it works)
	if [[ ${portNo} =~ ^" " ]]; then
		newPort=" ${newPort}"
	fi 
	afterRepl="${name}=${newPort}"

	# Keep the debug statements as optionals
	if [ $loud -gt 1 ]; then
		echo "File: ${filePath}1\nName: ${name}\nPort: ${portNo}\nRepl: ${afterRepl}"
	fi
	if [ $loud -gt 0 ]; then
		echo "${i} >>> ${filePath}:${afterRepl}"
		test $loud -gt 1 && echo "---"
	fi

	# --IMPORTANT--
	# If you're not on mac delete ''
	sed -i '' 's/'${beforeRepl}'/'${afterRepl}'/' "${filePath}"

done

test ${loud} -gt 0 && echo "Changing ${oldHostname} to ${hostname}...\n"

for i in $(grep ${oldHostname} $(find ${project}/etc -maxdepth 1 -type f)); do
	test ${loud} -gt 2 && echo ${i}

        # parsing grep output
        filePath=$(echo ${i} | cut -f1 -d ':')
	isChangeable ${filePath}
	if [[ $? -eq 1 ]]; then
                test ${loud} -gt 1 && echo "INFO: ${filePath} is not in the list of changeable files:\n${toChange[@]}\n---"
                continue
        fi
	test ${loud} -gt 0 && echo "Changing ${oldHostname} to ${hostname} in ${filePath}"
	test ${loud} -gt 1 && echo "---"

	# --IMPORTANT--
	# if you're not on mac delete ''
	sed -i '' 's/'${oldHostname}'/'${hostname}'/g' "${filePath}"

done

test ${loud} -gt 0 && echo "Running certNew.sh...\n"

IFS=${oldIFS}

oldCD=$(pwd)

cd ${project}/etc/certs
sh CertNew.sh -cn ${hostname} -san "DNS:${hostname}"
cd ${oldCD}

echo "\n---\nImporant ports that were changed: "
for i in ${isImportant[@]}; do
	egrep "^$i=(\s|[0-9])+$" $(find ${project}/etc -maxdepth 1 -type f) | cut -f2 -d ':'
done
echo "You're running on ${hostname}"

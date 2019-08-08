#!/usr/bin/env sh

realConf="build.config"
delimiter='building='

function getMasterBuilder() {
	if ! _checkBuildConf $1; then
		return 1
	fi
	
	egrep "^master=" $1/${realConf} | cut -f2 -d '='
}

function isHeroBuildable() {
    _checkBuildConf $@
}
function _checkBuildConf() {
	if [ $# -eq 1 ] && [ -f $1/${realConf} ]; then
		return 0
	fi
	return 1
}

function getRunningBuilds() {
	if ! _checkBuildConf $1; then
		return 1
	fi

	egrep "^building=" $1/${realConf} | cut -f2 -d '='
}

function getHeroRepo() {
	local master=$(getMasterBuilder $1)
	if [ -z ${master} ]; then
		return 1
	fi

	local builds=$(getRunningBuilds $1)

	(
		cd $1
		for i in $(/bin/ls -d */ | cut -f1 -d '/'); do
			# echo \"$i\"
			if [[ ${i} == "${master}" ]] || isCurrentlyBuilding $1 ${i}; then
				continue
			fi
				echo "$i"
				return 0
		done
		return 1
	)
}

function isCurrentlyBuilding() {
    if [ $# -ne 2 ] || ! _checkBuildConf $1; then
        return 1
    fi

    local repo=$2
    local dir=$1

    grep "{$repo}" "${dir}/${realConf}" &> /dev/null

}

function addToBuildConf() {
    if [ $# -ne 2 ] || ! _checkBuildConf $1; then
        return 1
    fi
    (
        cd $1
	    sed -i '' 's/'${delimiter}'/'${delimiter}\{${2}\},'/g' ${realConf}
	)
}

function removeFromBuildConf() {
    if [ $# -ne 2 ] || ! _checkBuildConf $1; then
        return 1
    fi
    (
        cd $1
	    sed -i '' 's/'\{${2}\},'//g' ${realConf}
	)
}

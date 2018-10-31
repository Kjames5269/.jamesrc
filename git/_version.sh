#!/usr/bin/env sh

function preversionHook() {
    # front-load the operation so there's no delay after git prints it's version
    commitTag=$( cd ${JRC_BASE_PATH} && git log --format="%h" | head -1 )
}

function postversionHook() {
    echo "jrc version 0.3-beta (${commitTag})"
    unset commitTag
}


function pre--versionHook() {
    preversionHook
}

function post--versionHook() {
    postversionHook
}
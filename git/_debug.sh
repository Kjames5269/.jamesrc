#!/bin/sh

function predebugHook() {

    if [ $# -ne 2 ]; then
        return $(echoerr "debug [debug|trace|info|off]")
    fi

    case $(echo $2 | tr "[A-Z]" "[a-z]" ) in
        "debug" | "on")
            GIT_DEBUG=1
            echoinf "Debug mode enabled with debug logs"
            ;;
        "trace")
            GIT_DEBUG=2
            echoinf "Debug mode enabled with trace logs"
            ;;
        *)
            echoinf "Debug mode disabled"
            GIT_DEBUG=0
            ;;
    esac

    return 2
}

function DEBUG() {
    # Get the return value of whatever came before it so $? can be used after DEBUG statements
    debugRetval=$?

    if [ -z ${GIT_DEBUG} ]; then
        return ${debugRetval}
    fi

    case $1 in
        "trace")
            debugLevel="trace"
            debugNo=2
            shift
            ;;
        *)
            debugLevel="debug"
            debugNo=1
            ;;
    esac
    debugCaller=$1
    shift
    test ${GIT_DEBUG} -ge ${debugNo} && echo${debugLevel} "${debugCaller}(): ${@}"
    unset debugCaller debugNo debugLevel

    return $debugRetval
}

function checkDebug() {
    if [ -z ${GIT_DEBUG} ]; then
        return 0
    fi
    return ${GIT_DEBUG}
}
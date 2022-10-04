#!/usr/bin/env bash
set -Ceu
#---------------------------------------------------------------------------
# mpchain APIのcreate_sendを叩く【Electron】
# CreatedAt: 2022-10-04
#---------------------------------------------------------------------------
Run() {
	THIS="$(realpath "${BASH_SOURCE:-0}")"; HERE="$(dirname "$THIS")"; PARENT="$(dirname "$HERE")"; THIS_NAME="$(basename "$THIS")"; APP_ROOT="$PARENT";
	cd "$HERE"
	[ -f 'error.sh' ] && . error.sh
	. install.sh
	npm start
}
Run "$@"

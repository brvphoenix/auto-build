#!/bin/bash

failure() {
	echo "Failed at line $1: $2"
}

trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

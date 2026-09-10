#!/bin/sh

command_arg="{$1:-}"
case "$command_arg" in
	"migrate")
		oldroot="{$2:-}"
		newroot="{$3:-}"

		;;

	*)

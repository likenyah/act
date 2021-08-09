#! /usr/bin/env sh
# SPDX-License-Identifier: 0BSD
# -----------------------------------------------------------------------------

##
# module.sh
#
# Usage: . "./modules/module.sh"
#
# This script is _not_ a module on its own and therefore should not be made
# executable. The purpose of this script is to provide common functions for
# POSIX sh(1)-based modules.
#
# NOTE: The modules included with act(1) are self contained; they do not depend
#       on this script. This is provided as a way to avoid writing redundant
#       code in your own modules.
##

: "${ACT_MODULE_NAME:="${0##*/}"}"
: "${ACT_PRIVESC:=""}"
: "${ACT_VERBOSE:="n"}"
: "${UNAME_n:="$(uname -n)"}"

# If we have netcat (nc(1)), use it to do remote logging.
if command -v "nc" >/dev/null 2>&1 && [ -S "log.socket" ]; then
	_act_logging="y"

	if [ ! -e "log.pipe" ]; then
		mkfifo "log.pipe"
	fi

	nc -NU -- "log.socket" <"log.pipe" &
	exec 9>"log.pipe"

else
	_act_logging="n"
	exec 9>/dev/null
fi

_atexit_eval=""
trap '_do_exit; ${_atexit_eval}' EXIT HUP INT QUIT TERM

##
# shquote - Quote a string for evaluation by sh(1).
#
# @1: String to quote.
#
# @return: None.
shquote()
{
	printf "%s\\n" "${1}" | sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

##
# requote - Quote a string for substitution into a regex(7).
#
# @1: String to quote.
#
# @return: None.
requote()
{
	printf "%s\\n" "${1}" | sed 's/[][$()*+.\/;?\\^{|}]/\\&/g'
}

##
# match - Match a string against a regex(7).
#
# @1: String to attempt to match.
# @2: POSIX Extended Regular Expression to match against.
#
# @return: 0 (true) if the pattern matches, non-zero (false) otherwise. (See
#          grep(1) for further exit statuses.)
match()
{
	printf "%s\\n" "${1}" | grep -Eq "${2}"
}

##
# checkyn - Attempt to determine the boolean value of a provided string.
#
# @1: String to check.
#
# @return: 0 (true) if matching a "true" value, 1 (false) if matching a "false"
#          value, 2 (false) otherwise.
checkyn()
{
	case "${1}" in
	[Yy1]|[Yy][Ee][Ss])
		return 0
		;;
	[Nn0]|[Nn][Oo])
		return 1
		;;
	*)
		return 2
		;;
	esac
}

##
# fnmatch - Match a string against a glob(7).
#
# @1: String to attempt to match.
# @2: Glob pattern to match against.
#
# @return: 0 (true) if the pattern matches, 1 (false) otherwise.
fnmatch()
{
	case "${1}" in
	${2})
		return 0
		;;
	*)
		return 1
		;;
	esac
}

##
# _do_exit - Execute module.sh-internal actions for cleanup at exit.
#
# @return: None
#
# NOTE: To be set as a trap by this script only.
_do_exit()
{
	if checkyn "${_act_logging}"; then
		pkill -u "$(id -u)" "nc -NU -- log.socket"
	fi
}

##
# atexit - Register commands to be executed at script exit.
#
# @...: Shell expression suitable for passing to eval(1).
#
# @return: None.
#
# NOTE: Each _argument_ must be a complete shell expression as every argument
#       is suffixed with a ";".
#
# This function should be used instead of manually setting a trap(1) in modules
# which include this file. (module.sh)
atexit()
{
	while [ -n "${1}" ]; do
		_atexit_eval="${_atexit_eval# } ${1};"
		shift
	done
}

##
# _do_printf - Internal printf(1) wrapper.
#
# @1:   A printf(3)-like format string.
# @...: Arguments corresponding to the provided format string.
#
# @return: See printf(1).
_do_printf()
{
	_do_printf_fmt="${1}"
	shift

	# shellcheck disable=SC2059
	printf "%s: ${_do_printf_fmt}\\n" "${ACT_MODULE_NAME}" "${@}" >&2
}

##
# log - Write a formatted message to the log file.
#
# @2:   Log level. See syslog(3) for expected levels.
# @2:   A printf(3)-like format string.
# @...: Arguments corresponding to the given format string.
#
# @return: See printf(1).
log()
{
	if ! checkyn "${_act_logging}"; then
		return 0
	fi

	_log_level="${1}"
	_log_fmt="${2}"
	shift 2

	# shellcheck disable=SC2059
	_log_msg="$(printf "${_log_fmt}\\n" "${@}")"

	printf "%s %s %s[%s]: %s: %s\\n" "$(date -u "+%Y-%m-%dT%H:%M:%SZ")" \
		"${UNAME_n}" "${ACT_MODULE_NAME}" "${$}" "${_log_level}" \
		"${_log_msg}" >&9
}

##
# msg - Write a formatted message.
#
# @1:   A printf(3)-like format string.
# @...: Arguments corresponding to the given format string.
#
# @return: See printf(1).
msg()
{
	log "NOTICE" "${@}"
	_do_printf "${@}"
}

##
# vmsg - Write a verbose message.
#
# @1:   A printf(3)-like format string.
# @...: Arguments corresponding to the given format string.
#
# @return: See printf(1).
vmsg()
{
	log "INFO" "${@}"
	if checkyn "${ACT_VERBOSE}"; then
		_do_printf "${@}"
	fi
}

##
# fatal - Print a formatted error message and exit.
#
# @1:   A printf(3)-like format string.
# @...: Arguments corresponding to the provided format string.
#
# @return: See printf(1).
fatal()
{
	_fatal_fmt="${1}"
	shift

	log "CRIT" "${_fatal_fmt}" "${@}"
	_do_printf "fatal: ${_fatal_fmt}" "${@}"
	exit 1
}

##
# module [-v] <module-name> [<module-arg>]...
#
# Execute <module-name>, if it exists, with the provided arguments. With -v,
# print the path to <module-name> but do not execute it.
#
# This function also saves/restores the values of OPTARG and OPTIND so may be
# used during option handling.
module()
{
	_module_OPTARG="${OPTARG}"
	_module_OPTIND="${OPTIND}"
	OPTARG=""
	OPTIND=1

	_module_print="n"
	_module_ret=2

	while getopts ":v" opt; do
		case "${opt}" in
		v)
			_module_print="y"
			;;
		*)
			printf "module: invalid option: -%s\\n" "${OPTARG}" >&2
			_module_fail="y"
			;;
		esac
	done
	shift "$((OPTIND - 1))"

	if ! checkyn "${_module_fail}" && [ -x "./modules/${1}" ]; then
		if checkyn "${_module_print}"; then
			printf "%s\\n" "./modules/${1}"
			_module_ret=0
		else
			_module_cmd="./modules/${1}"
			shift

			"${_module_cmd}" "${@}"
			_module_ret="${?}"
		fi
	fi

	OPTARG="${_module_OPTARG}"
	OPTIND="${_module_OPTIND}"
	return "${_module_ret}"
}

##
# priv - Execute a command as a privileged user.
#
# @...: Command to execute.
#
# @returns: Exit status of provided command.
priv()
{
	log "DEBUG" "priv: %s %s" "${ACT_PRIVESC}" "${*}"
	${ACT_PRIVESC} "${@}"
}

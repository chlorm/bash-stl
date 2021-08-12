# Copyright (c) 2014-2016, 2021, Cody Opel <cwopel@chlorm.net>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail

STL_LOG_LEVEL="${STL_LOG_LEVEL:-info}"

# shellcheck disable=SC2120
stl_rogram_name() {
    stl_func_reqargs '0' "$#"
    local -r name="${PROGRAM_NAME:-unknown}"
    if [ "$name" != 'unknown' ]; then
        echo "$name"
    else
        # Equivalent to `basename $0`
        echo "${0##*/}"
    fi
}

stl_func_reqargs() {
    local -r expected=$1
    local -r recieved=$2
    local -r overload="${STL_FUNC_OVERLOAD:-}" # Anything not null to enable
    local -r args=$#
    local expectedCheck=$expected
    local overloadStr=
    local plural

    # Self error
    if [ ! $args == 2 ]; then
        STL_LOG_FUNC="$FUNCNAME" stl_log_error \
            "expected \`2' arguments, but recieved \`$args'"
        return 1
    fi

    if [ -n "$overload" ]; then
        expectedCheck=$(($expected + 1))
        overloadStr='>='
    fi

    plural="$(if [ $expectedCheck -gt 1 ]; then echo 's'; fi)"
    if [[ $expected -ne $recieved && -z "$overload" ]] ||
        [[ -n "$overload" && $recieved -lt $expected ]]; then
        STL_LOG_FUNC="${FUNCNAME[1]}" stl_log_error \
            "expected $overloadStr$expected argument$plural, but recieved $recieved"
        return 1
    fi
}

# Print a debug message with the current function and command executed
# Usage: add `set -o functrace` & `trap 'stl_log_trace' DEBUG`
stl_log_func() {
    stl_func_reqargs '0' "$#"
    # Requires `set -o functrace` to allow traps on DEBUG & RETURN to be
    # inherited by shell functions, command substitutions, and commands
    # executed in a subshell environment.

    if [ "$stl_LOG_LEVEL" == 'trace' ]; then
        stl_log_debug "$BASH_COMMAND"
    fi
}

# Print a debug message with current function and custom message
# $1 - Level (trace,debug,info,warn,error,fatal)
# $2 - Message
stl_log_impl() {
    stl_func_reqargs '2' "$#"
    local -r -i descriptor="${STL_LOG_DESCRIPTOR:-2}"
    local -r func="${STL_LOG_FUNC:-${FUNCNAME[2]}}"
    local -r level="$1"
    # FIXME: what is the point of off?
    local -r -A levels=(
        ['off']=0
        ['fatal']=1
        ['error']=2
        ['warn']=3
        ['info']=4
        ['debug']=5
        ['trace']=6
    )
    local -r errorMessage="$2"

    if ! stl_type_int "${levels[$level]}" 2>&-; then
        printf '%s [error] %s: invalid debug level: %s\n' \
            "$(stl_rogram_name)" \
            "$FUNCNAME" \
            "$level" >&$descriptor
        return 1
    fi

    stl_type_str "$errorMessage"

    if [ ${levels[$level]} -le ${levels[$STL_LOG_LEVEL]} ]; then
        printf '%s [%s] %s: %s\n' \
            "$(stl_rogram_name)" \
            "$level" \
            "$func" \
            "$errorMessage" >&$descriptor
    fi
}
# FIXME: see above comment
#stl_log_off() { stl_log_impl 'off' "$1"; }
stl_log_fatal() { stl_log_impl 'fatal' "$1"; }
stl_log_error() { stl_log_impl 'error' "$1"; }
stl_log_warn() { stl_log_impl 'warn' "$1"; }
stl_log_info() { stl_log_impl 'info' "$1"; }
stl_log_debug() { stl_log_impl 'debug' "$1"; }
stl_log_trace() { stl_log_impl 'trace' "$1"; }

stl_log_trace() {
    stl_func_reqargs '0' "$#"
    local -i i=0
    local -i x=${#BASH_LINENO[@]}

    for ((i = x - 2; i >= 0; i--)); do
        printf '  File "%s", line %s, in %s\n' \
            "${BASH_SOURCE[i + 1]}" \
            "${BASH_LINENO[i]}" \
            "${FUNCNAME[i + 1]}"
        # Print the text from the line
        printf '    %s %s\n' \
            "${BASH_LINENO[i]}" \
            "${BASH_SOURCE[i + 1]}"
    done
}

stl_str_lower() { echo "${@,,}"; }
stl_str_lowerl() { echo "${@,}"; }
stl_str_lower_regex() {
    local -r regex="$1"
    shift
    echo "${@,,[$regex]}"
}
stl_str_lower_var() { declare -l "$1"; }
stl_str_upper() { echo "${@^^}"; }
stl_str_upperl() { echo "${@^}"; }
stl_str_upper_regex() {
    local -r regex="$1"
    shift
    echo "${@^^[$regex]}"
}
stl_str_upper_var() { declare -u "$1"; }
#stl_str_inversecase() { echo "${@~~}" ; }
#stl_str_inversecase_first() { echo "${@~}" ; }

# Detect data type
stl_type_impl() {
    stl_func_reqargs '1' "$#"
    local -r var="$1"

    if [[ $var =~ ^-?[0-9]+\.[0-9]+$ ]]; then
        echo 'float'
    elif [[ $var =~ ^-?[0-9]+$ ]]; then
        echo 'integer'
    elif [ "$var" == true ] || [ "$var" == false ]; then
        echo 'boolean'
    elif [ ! -z "$var" ]; then
        echo 'string'
    else
        echo 'null'
    fi
}

stl_type_bool() {
    stl_func_reqargs '1' "$#"
    local _type
    local -r var="$1"

    _type="$(stl_type_impl "$var")"

    [ "$_type" == 'boolean' ] || {
        stl_log_error "Value is a ${_type}, while a boolean was expected"
        return 1
    }
}

stl_type_float() {
    stl_func_reqargs '1' "$#"
    local _type
    local -r var="$1"

    _type="$(stl_type_impl "$var")"

    [ "$_type" == 'float' ] || {
        stl_log_error "Value is a ${_type}, while a float was expected"
        return 1
    }
}

stl_type_int() {
    stl_func_reqargs '1' "$#"
    local _type
    local -r var="$1"

    _type="$(stl_type_impl "$var")"

    [ "$_type" == 'integer' ] || {
        stl_log_error "Value is a ${_type}, while an integer was expected"
        return 1
    }
}

stl_type_null() {
    stl_func_reqargs '1' "$#"
    local _type
    local -r var="$1"

    _type="$(stl_type_impl "$var")"

    [ "$_type" == 'null' ] || {
        stl_log_error "Value is a ${_type}, while null was expected"
        return 1
    }
}

stl_type_str() {
    stl_func_reqargs '1' "$#"
    local _type
    local -r var="$1"

    _type="$(stl_type_impl "$var")"

    [ "$_type" != 'null' ] || {
        stl_log_error "Value is a ${_type}, while string was expected"
        return 1
    }
}

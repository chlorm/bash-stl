# Copyright (c) 2014-2016, Cody Opel <codyopel@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# TODO: add ensure dir/file, sudo wrap, symlink, proc, run

################################# Dependencies #################################

# Bash 4.2+
# GNU awk
# GNU grep
# GNU sed

##################################### Main #####################################

set -o errexit
set -o errtrace
set -o functrace
# TODO: fix remaining undeclared variables (mainly in concurrent)
#set -o nounset
set -o pipefail

Main::Name() {
  if [ -n "${PROGRAM_NAME}" ] ; then
    echo "${PROGRAM_NAME}"
  else
    echo "$(basename "${0}")"
  fi
}

################################## Arguments ###################################

# FIXME: add support for using arrays instead of variables (prepend/append)
# FIXME: add required boolean (if flag must be set)

# Options:
# short       - 'short=<flag>' (e.g. -f)
# long        - 'long=<flag>' (e.g. --flag)
# description - 'desc=<description>'
# default     - ''
# value       - ''
# variable    - ''
Args::Define() {
  [ $# -ge 3 ]

  for ((i=1; i<=$#; i++)) ; do
    local option key value
    eval option="\$${i}"
    key="$(echo ${option} | awk -F'=' '{print $1}')"
    value="$(echo ${option} | awk -F'=' '{print $2}')"

    String::NotNull "${key}"
    String::NotNull "${value}"

    case "${key}" in
      'default') local default="${value}" ;;
      'desc') local desc="${value}" ;;
      'long')
        [ ${#value} -gt 1 ]
        local long="--${value}"
        ;;
      'short')
        [ ${#value} -eq 1 ]
        local shortname="${value}"
        local short="-${shortname}"
        ;;
      'value') local val="${value}" ;;
      'variable') local variable="${value}" ;;
      'boolean') local boolean="${value}"
    esac
  done

  [ -n ${variable+x} ]
  String::NotNull "${long}"

  # Usage message
  ArgsUsage="${ArgsUsage}${ArgsUsage:+#NL}    ${short} $(printf "%-12s %s" "${long}:" "${desc}")${default:+ [default:$default]}"
  # Translate long options to short options
  ArgsCaseStatements="${ArgsCaseStatements}#NL#TB#TB${long})#NL#TB#TB#TBparams=\"\$params ${short}\";;"

  # Default
  if [ -n "${default}" ] ; then
    ArgDefaults="${ArgDefaults}#NL${variable}=${default}"
  fi

  req_input() {
    if [ -z "${boolean}" ] && [ -n "${variable}" ] ; then
      echo ":"
    fi
  }

  # GetOpts arguments
  GetOptsArgumentString="${GetOptsArgumentString} ${shortname}$(req_input)"
  GetOptsCaseStatements="${GetOptsCaseStatements}#NL${shortname})#NL${variable}=\"\$OPTARG\";;"
}

# FIXME: if long flag is used return long flag in error message
# FIXME: throw an error if both the short & long flag are used
# FIXME: fix parsing of input with spaces
Args::Build(){
  local ArgFile
  local Name
  local -A ReplaceChars
  local TMPDIR

  Name="$(Main::Name)"
  TMPDIR="$(mktemp -d)"
  ArgFile="${TMPDIR}/optparse-${RANDOM}.tmp"

  # Building getopts header here

  # Function usage
  cat <<EOF > "${ArgFile}"
local params param arg

function ${Name}::Usage(){
cat <<USAGE
usage: ${Name} [OPTIONS]

OPTIONS:
${ArgsUsage}

    -h --help:      usage

USAGE
}

# Translate long options to short options
params=""
while [ \$# -ne 0 ] ; do
  param="\$1" ; shift

  case "\$param" in
    ${ArgsCaseStatements}
    '-h'|'--help')
      ${Name}::Usage
      exit 0
      ;;
    *)
      if [[ "\$param" == --* ]] ; then
        echo -e "Unrecognized option: \$param"
        ${Name}::Usage
        exit 1
      fi
      params="\$params \"\$param\""
      ;;
  esac
done

eval set -- "\$params"

# Set default variable values
${ArgDefaults}

# Process using getopts
while getopts ":${GetOptsArgumentString}" arg ; do
  case "\${arg}" in
    # Substitute actions for different variables
    ${GetOptsCaseStatements}
    :) echo "Option - \${OPTARG} requires an argument" ; exit 1 ;;
    *) ${Name}::Usage ; exit 1 ;;
  esac
done

# Clean up after self
rm "${ArgFile}"

EOF

  ReplaceChars=( ['#NL']='\n' ['#TB']='\t' )

  for i in "${!ReplaceChars[@]}"; do
    sed -i "${ArgFile}" \
      -e "s/${i}/${ReplaceChars[$i]}/g"
  done

  # Unset global variables
  unset ArgsUsage
  unset ArgsCaseStatements
  unset GetOptsCaseStatements
  unset GetOptsArgumentString
  unset ArgDefaults

  # Return file name to parent
  echo "${ArgFile}"
}

##################################### CPU ######################################

# TODO: implement proper numa support

# Return CPU architecture without endianness or address space size
Cpu::Architecture() {
  # Do NOT use `uname -m' to achieve this functionality.
  local Architecture

  case "$(OS::Kernel)" in
    'cygwin')
      case "${PROCESSOR_ARCHITECTURE}" in
        'AMD64') Architecture='x86_64' ;;
        'x86') Architecture='i686' ;;
      esac
      ;;
    # TODO: use sysctl on Darwin
    'darwin') Architecture='x86_64' ;;
    'linux')
      Architecture="$(
        lscpu |
          grep --max-count 1 --only-matching --extended-regex 'arm|i686|x86_64'
      )"
      ;;
  esac

  String::NotNull "${Architecture}"

  echo "${Architecture}"
}

# Find CPU address space size (ie. 32bit/64bit)
Cpu::AddressSpace() {
  local AddressSpace

  AddressSpace=$(
    getconf LONG_BIT |
      grep --max-count 1 --only-matching --extended-regex '8|16|32|64|128'
  )

  String::NotNull "${AddressSpace}"

  echo "${AddressSpace}"
}

Cpu::Sockets() {
  local Sockets

  case "$(OS::Kernel)" in
    'darwin') Sockets=1 ;;
    'linux')
      Sockets="$(
        lscpu |
          grep --max-count 1 'Socket(s):' |
          grep --only-matching --perl-regexp "[0-9]+"
      )"
      ;;
  esac

  if [ ! ${Sockets} -ge 1 ] ; then
    # Assume a socket exists even if it fails to find any
    Sockets=1
  fi

  echo "${Sockets}"
}

# Find number of physical cpu cores
Cpu::Physical() {
  # Assumes all sockets are identical, only some arm platforms
  # won't work with this logic.

  local CpuCores

  case "$(OS::Kernel)" in
    'linux')
      CpuCores=$(
        lscpu |
          grep --max-count 1 'Core(s) per socket:' |
          grep --only-matching --perl-regexp '[0-9]+'
      )
      ;;
    'darwin')
      CpuCores=$(
        sysctl hw |
          grep --max-count 1 'hw.physicalcpu:' |
          grep --only-matching --perl-regexp '[0-9]+'
      )
      ;;
    'cygwin')
      CpuCores=$(
        NUMBER_OF_PROCESSORS |
          grep --only-matching --perl-regexp '[0-9]+'
      )
      ;;
  esac

  if [ -z "${CpuCores}" ] ; then
    CpuCores=1
  else
    CpuCores=$(( ${CpuCores} * $(Cpu::Sockets) ))
  fi

  echo "${CpuCores}"
}

# Find number of logical cpu cores
Cpu::Logical() {
  # Assumes all sockets are identical, only some arm platforms won't
  # work with this logic

  local CpuThreads

  case $(OS::Kernel) in
    'linux'|'freebsd')
      # Finds number of logical threads per physical core
      CpuThreads=$(
        lscpu |
          grep --max-count 1 'Thread(s) per core:' |
          grep --only-matching --perl-regexp '[0-9]+'
      )
      if [ -n "${CpuThreads}" ] ; then
        # Convert to number of threads per cpu
        CpuThreads=$(( ${CpuThreads} * $(Cpu::Physical) ))
      fi
      ;;
    'darwin')
      CpuThreads=$(
        sysctl hw |
          grep --max-count 1 "hw.logicalcpu:" |
          grep --only-matching --perl-regexp '[0-9]+'
      )
      ;;
  esac

  if [ -z "${CpuThreads}" ] ; then
    CpuThreads=$(Cpu::Physical)
  else
    CpuThreads=$(( ${CpuThreads} * $(Cpu::Sockets) ))
  fi

  echo "${CpuThreads}"
}

#################################### Debug #####################################

# Print a debug message with the current function and command executed
# Usage: add `set -o functrace` & `trap 'Debug::Message' DEBUG`
Debug::Func() {
  # Requires `set -o functrace` to allow traps on DEBUG & RETURN to be
  # inherited by shell functions, command substitutions, and commands
  # executed in a subshell environment.

  if [ "${ENABLE_DEBUGGING_VERBOSE}" == 'true' ] ; then
    echo "DEBUG: ${FUNCNAME[1]} - ${BASH_COMMAND}" > /dev/null 1>&2
  fi
}

# Print a debug message with current function and custom message
Debug::Message() {
  local Message="${1}"

  if [ -z "${Message}" ] ; then
    Error::Message 'no input'
  fi

  if [ "${ENABLE_DEBUGGING}" == 'true' ] ; then
    echo "DEBUG: ${FUNCNAME[1]} - ${Message}" > /dev/null 1>&2
  fi
}

################################## Directory ###################################

Directory::Create() {
  while [ "${1}" ] ; do
    # Make sure directory is not a symlink
    if [ -L "${1}" ] ; then
      unlink "${1}" > /dev/null 2>&1
    fi
    # Create directory
    if [ ! -d "${1}" ] ; then
      mkdir -p "${1}" > /dev/null 2>&1
    fi
    shift
  done
}

Directory::Remove() {
  while [ "${1}" ] ; do
    # Make sure directory is not a symlink
    if [ -L "${1}" ] ; then
      unlink "${1}" > /dev/null 2>&1
    fi
    # Remove directory
    if [ -d "${1}" ] ; then
      rm -rf "${1}" > /dev/null 2>&1
    fi
    shift
  done
}

################################### Download ###################################

# TODO: add support for ftp, and reduce support to either curl or wget

Download::Http() {
  if Path::Check 'curl' ; then
    curl -sOL $@
  elif Path::Check 'wget' ; then
    wget $@
  elif Path::Check 'fetch' ; then
    fetch $@
  else
    Error::Message 'no supported download utility found'
    return 1
  fi
}

#################################### Error #####################################

# TODO: multiple error levels, fatal/error/warn

Error::Message() {
  if [ -n "${2}" ] ; then
    echo "$(Main::Name): ERROR in \`${2}\`: ${1}" > /dev/stderr
  else
    echo "$(Main::Name): ERROR in \`${FUNCNAME[1]}\`: ${1}" > /dev/stderr
  fi
}

Error::Trace() {
  local i=0
  local x=${#BASH_LINENO[@]}

  for ((i=x-2; i>=0; i--)) ; do
    echo '  File' \"${BASH_SOURCE[i+1]}\", line ${BASH_LINENO[i]}, in ${FUNCNAME[i+1]}
    # Print the text from the line
    sed -n "${BASH_LINENO[i]}{s/^/    /;p}" "${BASH_SOURCE[i+1]}"
  done
}

##################################### File #####################################

File::Create() {
  while [ "${1}" ] ; do
    # Make sure file is not a symlink
    if [ -L "${1}" ] ; then
      unlink "${1}" > /dev/null 2>&1
    fi
    # Create file
    if [ ! -f "${1}" ] ; then
      touch "${1}" > /dev/null 2>&1
    fi
    shift
  done
}

File::Remove() {
  while [ "${1}" ] ; do
    # Make sure file is not a symlink
    if [ -L "${1}" ] ; then
      unlink "${1}" > /dev/null 2>&1
    fi
    # Remove file
    if [ -f "${1}" ] ; then
      rm -f "${1}" > /dev/null 2>&1
    fi
    shift
  done
}

##################################### Math #####################################

Math::Mode() {
  echo "${@}" |
    # Break string on spaces
    sed -r 's/[[:space:]]+/\n/g' |
    # Remove duplicates
    uniq -c |
    # Sort the most common first
    sort -n -k 1 -r |
    awk '{ print $2 ; exit }'
}

Math::Mode.count() {
  echo "${@}" |
    # Break string on spaces
    sed -r 's/[[:space:]]+/\n/g' |
    # Remove duplicates
    uniq -c |
    # Sort the most common first
    sort -n -k 1 -r |
    awk '{ print $1 ; exit }'
}

###################################### OS ######################################

# TODO: OS architecture functions

#OS::AddressSpace

#OS::Architecture

#OS::Endianness

OS::Kernel.proc() { cat /proc/version 2> /dev/null ; }

OS::Kernel.ostype() { echo "${OSTYPE}" > /dev/null 2>&1 ; }

OS::Kernel.uname() { uname -s 2> /dev/null ; }

# Find host os kernel
OS::Kernel() {
  local Kernel

  Kernel=$(
    String::LowerCase "$(OS::Kernel.proc) $(OS::Kernel.ostype) $(OS::Kernel.uname)" |
      grep --max-count 1 --only-matching --extended-regex \
        'microsoft|cygwin|darwin|freebsd|linux' |
      head -1
  )

  if [ "${Kernel}" == 'microsoft' ] ; then
    Kernel='windows'
  fi

  String::NotNull "${Kernel}"

  echo "${Kernel}"
}

# Find linux distro via /etc/*-release
OS::Linux.release() { cat ${ROOT}/etc/*-release 2>/dev/null ; }
# Find linux distro via uname -a
OS::Linux.uname() { uname -a 2>/dev/null ; }
# Find linux distro via linux standard base
OS::Linux.lsb() { lsb_release -a 2>/dev/null ; }
# Take first result of linux os name match
OS::Linux() {
  [ "$(OS::Kernel)" == 'linux' ]

  local Linux

  Linux="$(
    String::LowerCase \
      "$(OS::Linux.release) $(OS::Linux.uname) $(OS::Linux.lsb)" |
      grep --only-matching --extended-regex \
        'arch|centos|debian|fedora|gentoo|nixos|opensuse|red hat|slackware|suse|triton|ubuntu' |
      head -1
  )"

  String::NotNull "${Linux}"

  echo "${Linux}"
}

##################################### Path #####################################

# Add direcory to $PATH
Path::Add() {
  [ -d "${1}" ]
  if [ -z "$(echo "${PATH}" | grep "${1}" 2> /dev/null)" ] ; then
    export PATH="${PATH}:${1}"
  fi
}

# Remove directory from $PATH
Path::Remove() {
  if [ -n "$(echo "${PATH}" | grep "${1}" 2> /dev/null)" ] ; then
    export PATH=`echo -n $PATH | awk -v RS=: -v ORS=: '$0 != "'$1'"' | sed 's/:$//'`
  fi
}

# Finds the path to the binary
# TODO: print $3+ in case of paths with spaces
Path::Bin() { type -P "${1}" | awk '{ print $3 ; exit }' ; }

# Resolves the absolute path of a binary
Path::Bin.abs() {
  local IFS=:
  local PossiblePath

  for PossiblePath in ${PATH} ; do
    PossiblePath="$(readlink -f "${PossiblePath}/${1}")"
    if test -e "${PossiblePath}" ; then
      echo "${PossiblePath}"
      return 0
    fi
  done

  return 1
}

# Test to see if a binary exists in the path
Path::Check() { type "${1}" > /dev/null 2>&1 ; }

#################################### Prompt ####################################

Prompt::PasswordConfirmation() {
  local Pass1 Pass2

  while true ; do
    read -s -p "Password: " Pass1 ; echo
    read -s -p "Confirm: " Pass2 ; echo
    if [ "${Pass1}" == "${Pass2}" ] ; then
      break
    fi
    echo "WARNING: passwords do not match, try again"
  done

  echo "${Pass1}" > /dev/null 2>&1

  return 0
}

# Ask a yes or no question
Prompt::YorN() {
  local Answer
  local Default=2
  local Prompt

  case "${2}" in
    '') Default=2 ; Prompt='(y/n)' ;;
    'y') Default=0 ; Prompt='(Y/n)' ;;
    'n') Default=1 ; Prompt='(y/N)' ;;
    *) Default=2 ; Prompt='(y/n)' ;;
  esac

  while true ; do
    read -p "${1} ${Prompt}: " Answer
    case "$(String::LowerCase "${Answer}")" in
      # FIXME: don't return error code (using errexit)
      '') [ ! ${Default} -eq 2 ] && return ${Default} ;;
      'y'|'yes') break && return 0 ;;
      'n'|'no') break && return 1 ;;
    esac
    echo "WARNING: Response must be y/n or yes/no, try again"
  done

  return 2
}

#################################### String ####################################

# TODO: refactor into generic functions
String::NotNull() {
  if [ -z "${1}" ] ; then
    Error::Message 'value is null while a string was expected' "${FUNCNAME[1]}"
    return 1
  fi
}
String::LowerCase() { echo ${@,,} ; }
String::LowerCase.left() { echo ${@,} ; }
String::LowerCase.custom() {
  local regex
  regex="${1}" ; shift
  echo ${@,,[${regex}]}
}
String::LowerCase.var() { declare -l ${1} ; }
String::UpperCase() { echo ${@^^} ; }
String::UpperCase.left() { echo ${@^} ; }
String::UpperCase.custom() {
  local regex="${1}" ; shift
  echo ${@^^[${regex}]}
}
String::UpperCase.custom() { declare -u ${1} ; }
String::InverseCase()  { echo ${@~~} ; }
String::InverseCase.first()  { echo ${@~} ; }
String::Version() {
  [ $# -eq 2 ]
  if [ "${1}" == "${2}" ] ; then
    echo 'eq' ; return 0
  fi
  local IFS=.
  local i ver1=(${1}) ver2=(${2})
  # fill empty fields in ver1 with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)) ; do
      ver1[i]=0
  done
  for ((i=0; i<${#ver1[@]}; i++)) ; do
    if [[ -z ${ver2[i]} ]] ; then
      # fill empty fields in ver2 with zeros
      ver2[i]=0
    elif ((10#${ver1[i]} > 10#${ver2[i]})) ; then
      echo 'gt' ; return 0
    elif ((10#${ver1[i]} < 10#${ver2[i]})) ; then
      echo 'lt' ; return 0
    fi
  done
  Error::Message 'version comparison failed'
  return 1
}
String::Version.atleast() { [[ "$(String::Version "${1}" "${2}")" == +('eq'|'gt') ]] ; }
String::Version.nomore() { [[ "$(String::Version "${1}" "${2}")" == +('eq'|'lt') ]] ; }
String::Version.greater() { [[ "$(String::Version "${1}" "${2}")" == 'gt' ]] ; }
String::Version.lesser() { [[ "$(String::Version "${1}" "${2}")" == 'lt' ]] ; }

################################### Symlink ####################################

Symlink::Create() {
  Directory::Create "$(dirname "${2}")"
  # Ignore if a symlink already exists and points to the correct location.
  if [ "$(readlink -f "${2}")" != "${1}" ] ; then
    rm -rf "${2}"
    [ -e "${1}" ]
    ln -sf "${1}" "${2}"
  fi
}

##################################### User #####################################

# Determine if the user is root
User::Root() { [ $(id -u) -eq 0 ] ; }

################################## Concurrent ################################## 

# Copyright (c) 2016, Matthew Tardiff
# All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Version: 2.3.2
# https://github.com/themattrix/bash-concurrent

# Upstream bash-concurrent is designed primarily as a TUI and requires the
# shell to be an interactive session, which prevents using it as a library.
# This fork'd version focuses on making concurrent usable without a TUI.

# TODO:
# - Port logging to Logging::
#   - disable logging be default
# - Make TUI optional
# - Fix file arg passing.
#   Concurent currently fails if to many arguments a passed at once because Bash
#   has a limit for how many arguments a function can except.  Support for
#   passing arguments as a file would circumvent this behavior.

concurrent() (
    #
    # General Utilities
    #

    __crt__hide_failure() {
      "${@}" 2> /dev/null || :
    }

    #
    # Compatibility Check
    #

    if [[ -z "${BASH_VERSINFO[@]}" || "${BASH_VERSINFO[0]}" -lt 4 || "${BASH_VERSINFO[1]}" -lt 2 ]]; then
      Error::Message "Requires Bash version 4.2 for 'declare -g' (you have ${BASH_VERSION:-a different shell})"
    fi

    __crt__unset_env() {
        # Unset all concurrent-related configuration environment variables.
        unset CONCURRENT_DRY_RUN
    }

    __crt__unset() {
        local sub_namespace=${1}
        if [[ -n "${sub_namespace}" ]]; then
            local namespace="__crt__${sub_namespace}__"
        else
            local namespace="__crt__"
        fi
        # shellcheck disable=SC2046
        unset -f $(compgen -A function "${namespace}")
        # shellcheck disable=SC2046
        unset $(compgen -v "${namespace}")
    }

    __crt__unset 'help'

    #
    # Settings
    #

    __crt__ORIG_PWD=${PWD}
    __crt__ORIG_OLDPWD=${OLDPWD}
    __crt__ORIG_BASHOPTS=${BASHOPTS}
    __crt__ORIG_SHELLOPTS=${SHELLOPTS}

    __crt__set_original_pwd() {
        cd "${__crt__ORIG_PWD}"
        export OLDPWD=${__crt__ORIG_OLDPWD}
    }

    __crt__set_our_shell_options() {
        set -o errexit      # Exit on a failed command...
        set -o pipefail     # ...even if that command is in a pipeline.
        shopt -s nullglob   # Empty glob evaluates to nothing instead of itself
    }

    __crt__set_original_shell_options() {
        __crt__set_our_shell_options
        [[ "${__crt__ORIG_SHELLOPTS}" == *errexit*  ]] || set +o errexit
        [[ "${__crt__ORIG_SHELLOPTS}" == *pipefail* ]] || set +o pipefail
        [[ "${__crt__ORIG_BASHOPTS}"  == *nullglob* ]] || shopt -u nullglob
    }

    __crt__set_our_shell_options

    #
    # Task Management
    #

    __crt__is_task_started() {
        [[ -z "${__crt__pending[${1}]}" ]]
    }

    __crt__is_task_done() {
        [[ -n "${__crt__codes[${1}]}" ]]
    }

    __crt__are_all_tasks_done() {
        [[ "${__crt__running_task_count}" -eq 0 ]]
    }

    __crt__is_task_running() {
        __crt__is_task_started "${1}" && ! __crt__is_task_done "${1}"
    }

    __crt__is_under_concurrent_limit() {
        [[ "${CONCURRENT_LIMIT}" -lt 1 || "${__crt__running_task_count}" -lt "${CONCURRENT_LIMIT}" ]]
    }

    __crt__clear_event_pipe() {
        > "${__crt__event_pipe}"
    }

    __crt__name_index() {
      local name=${1}
      local i
      for i in "${!__crt__names[@]}"; do
        if [[ "${__crt__names[${i}]}" == "${name}" ]]; then
          printf '%s' "${i}"
          return
        fi
      done
      Error::Message "Failed to find task named '${name}'"
    }

    __crt__is_task_allowed_to_start() {
      # A task is allowed to start if:
      #   1. it has not already started, and if
      #   2. all prereq tasks have succeeded, and if
      #   3. the process has not been interrupted.
      # If any prereqs have failed or have been skipped, then this task will
      # be skipped.

      local task=${1}
      if __crt__is_task_started "${task}"; then
        return 1  # cannot start again
      fi

      local requires
      local prereqs="__crt__prereqs_${task}[@]"
      for requires in "${!prereqs}"; do
        if [[ -z "${__crt__codes[${requires}]}" ]]; then
          return 1
        elif [[ "${__crt__codes[${requires}]}" != "0" ]]; then
          __crt__skip_task "${task}" "${__crt__names[${requires}]}"
          return 1
        fi
      done

      if [[ "${__crt__interrupted}" -eq 1 ]]; then
          __crt__mark_task_as_interrupted "${task}"
          return 1
      fi

      # All prereqs succeeded! This task can be started.
    }

    __crt__mark_task_with_code() {
        local task=${1}
        local code=${2}
        echo "task:${task}:${code}" >> "${__crt__event_pipe}"
    }

    __crt__task_runner() (
        # Do not create real variables for these so that they do not override
        # names from the parent script.
        # $1: task index
        # $2: command args array
        # $3: status dir
        # $4: event pipe
        set -- "${1}" "__crt__command_${1}[@]" "${__crt__status_dir}" "${__crt__event_pipe}"

        # Copy the command over since we're unsetting the __crt__ variables.
        CONCURRENT_COMMAND=("${!2}")

        # Reset any existing signal handlers.
        trap -- - INT EXIT

        # Allow nested tasks to refer to parent tasks.
        CONCURRENT_TASK_NAME+=("${__crt__names[${1}]}")
        export CONCURRENT_TASK_NAME

        set +o errexit  # a failure of the command should not exit the task
        (
            __crt__set_original_pwd
            __crt__set_original_shell_options
            __crt__unset_env
            __crt__unset

            "${CONCURRENT_COMMAND[@]}" 3>&1 &> "${3}/${1}" < /dev/null |
            while read -r meta; do
                printf "meta:%d:%s\n" "${1}" "${meta}" >> "${4}"
            done
            exit "${PIPESTATUS[0]}"
        )
        code=$?
        set -o errexit  # ...but other failures should

        __crt__mark_task_with_code "${1}" "${code}"
    )

    __crt__mark_task_as_started() {
        if [[ -n "${__crt__pending[${1}]}" ]]; then
            unset "__crt__pending[${1}]"
            (( __crt__running_task_count++ )) || :
        fi
    }

    __crt__mark_task_as_stopped() {
        local index=${1}
        local code=${2}

        if [[ -z "${__crt__codes[${index}]}" ]]; then
            (( __crt__running_task_count-- )) || :
            if   [[ "${code}" == '0'    ]]; then (( __crt__success_task_count++ ))     || :
            elif [[ "${code}" == 'skip' ]]; then (( __crt__skipped_task_count++ ))     || :
            elif [[ "${code}" == 'int'  ]]; then (( __crt__interrupted_task_count++ )) || :
            else                                 (( __crt__failure_task_count++ ))     || :
            fi
        fi
    }

    __crt__start_task() {
        __crt__task_runner "${1}" &
        __crt__mark_task_as_started "${1}"
        __crt__draw_status "${1}" running
    }

    __crt__start_all_tasks() {
        __crt__draw_initial_tasks
        __crt__move_cursor_to_top
        __crt__start_allowed_tasks
    }

    __crt__mark_task_as_interrupted() {
        __crt__mark_task_as_started "${1}"
        printf '[INTERRUPTED]\n' >> "${__crt__status_dir}/${1}"
        printf 'task:%d:int\n' "${1}" >> "${__crt__event_pipe}"
    }

    __crt__mark_all_running_tasks_as_interrupted() {
      local i
      for (( i = 0; i < __crt__task_count; i++ )); do
        if __crt__is_task_running "${i}"; then
          __crt__mark_task_as_interrupted "${i}"
        fi
      done
    }

    __crt__skip_task() {
        __crt__mark_task_as_started "${1}"
        echo "[SKIPPED] Prereq '${2}' failed or was skipped" > "${__crt__status_dir}/${1}"
        __crt__mark_task_with_code "${1}" skip
    }

    __crt__start_allowed_tasks() {
        local __crt__i
        for __crt__i in "${__crt__pending[@]}"; do
            __crt__is_under_concurrent_limit || break
            if __crt__is_task_allowed_to_start "${__crt__i}"; then
                __crt__start_task "${__crt__i}"
            fi
        done
    }

    __crt__save_stdin_stream() {
        exec 4<&0  # duplicate stdin stream to fd 4
    }

    __crt__restore_stdin_stream() {
        exec 0<&4  # restore original stdin stream from fd 4
    }

    __crt__wait_for_all_tasks() {
        __crt__start_animation
        __crt__save_stdin_stream
        __crt__run_event_loop
        __crt__status_cleanup
        __crt__stop_animation
        wait  # wait for all (completed) tasks
        __crt__restore_stdin_stream
    }

    __crt__run_event_loop() {
        # Main event loop! Each line read from the event pipe is an event to
        # handle. We can exit the loop once all tasks have completed.
        local __crt__event
        local __crt__tail_pipe="${__crt__status_dir}/tail-pipe"

        rm -f  "${__crt__tail_pipe}"
        mkfifo "${__crt__tail_pipe}"

        tail -n +0 -f "${__crt__event_pipe}" >> "${__crt__tail_pipe}" &
        __crt__tail_pid=$!

        while read -r __crt__event; do
            if [[ "${__crt__event}" == task:* ]]; then
                __crt__handle_done_task "${__crt__event#task:}"
                if __crt__are_all_tasks_done; then
                    break
                fi
            elif [[ "${__crt__event}" == anim:* ]]; then
                __crt__update_running_status_frames
            elif [[ "${__crt__event}" == meta:* ]]; then
                __crt__manage_meta "${__crt__event#meta:}"
            fi
        done < "${__crt__tail_pipe}"

        __crt__cleanup_event_loop
    }

    __crt__cleanup_event_loop() {
        if [[ -n "${__crt__tail_pid}" ]]; then
            __crt__hide_failure kill "${__crt__tail_pid}"
            __crt__hide_failure wait "${__crt__tail_pid}"
        fi
    }

    __crt__handle_done_task() {
        local index=${1%%:*}
        local code=${1#*:}
        __crt__mark_task_as_stopped "${index}" "${code}"
        __crt__codes["${index}"]=${code}
        __crt__draw_status "${index}" "${code}"
        #cp -- "${__crt__status_dir}/${index}" "${CONCURRENT_LOG_DIR}/${index}. ${__crt__names[${index}]//\//-} (${code}).log"
        if [[ "${code}" != "0" ]]; then
            __crt__final_status=1
        fi
        __crt__start_allowed_tasks
    }

    __crt__start_animation() {
        __crt__update_running_status_frames
        while true; do
            sleep "${__crt__seconds_between_frames}"
            echo "anim:" >> "${__crt__event_pipe}"
        done &
        __crt__animation_pid=$!
    }

    __crt__stop_animation() {
        __crt__hide_failure kill "${__crt__animation_pid}"
        __crt__hide_failure wait "${__crt__animation_pid}"
    }

    __crt__manage_meta() {
        local index=${1%%:*}
        local meta=${1#*:}
        __crt__meta["${index}"]=${meta}
        __crt__draw_meta "${index}"
    }

    #
    # Argument Parsing
    #

    __crt__names=()        # task names by index
    __crt__meta=()         # metadata strings by index
    __crt__pending=()      # indexes of tasks which haven't been started yet
    __crt__codes=()        # task exit codes (unset, 0-255, 'skip', or 'int') by index
    __crt__groups=()       # array of task indexes before which --and-then flags were specified
    __crt__task_count=0    # total number of tasks
    __crt__final_status=0  # 0 if all tasks succeeded, 1 otherwise
    __crt__interrupted=0   # 1 if script has been interrupted, 0 otherwise

    # Only allow this many tasks running at a time.
    export CONCURRENT_LIMIT=${CONCURRENT_LIMIT:-50}
    __crt__running_task_count=0

    __crt__success_task_count=0
    __crt__failure_task_count=0
    __crt__skipped_task_count=0
    __crt__interrupted_task_count=0

    # Arrays of command arguments by task index <T>:
    #   __crt__command_<T>=(...)
    #
    # Arrays of prerequisite task indices by task index <T>:
    #   __crt__prereqs_<T>=(...)
    #
    # These are dynamically created during argument parsing since bash doesn't
    # have a concept of nested lists.

    __crt__args__task_delimiter=${1}

    __crt__args__is_task_flag()        { [[ "${1}" == "${__crt__args__task_delimiter}" ]]; }
    __crt__args__is_group_flag()       { [[ "${1}" == "--and-then"    ]]; }
    __crt__args__is_require_flag()     { [[ "${1}" == "--require"     ]]; }
    __crt__args__is_require_all_flag() { [[ "${1}" == "--require-all" ]]; }
    __crt__args__is_before_flag()      { [[ "${1}" == "--before"      ]]; }
    __crt__args__is_before_all_flag()  { [[ "${1}" == "--before-all"  ]]; }
    __crt__args__is_sequential_flag()  { [[ "${1}" == "--sequential"  ]]; }

    __crt__args__is_flag_starting_section() {
        __crt__args__is_task_flag "${1}" ||
        __crt__args__is_group_flag "${1}" ||
        __crt__args__is_require_flag "${1}" ||
        __crt__args__is_require_all_flag "${1}" ||
        __crt__args__is_sequential_flag "${1}"
    }

    __crt__args__is_item_in_array() {
        local item_to_find=${1}
        local array_name="${2}[@]"
        local i
        for i in "${!array_name}"; do
            if [[ "${i}" == "${item_to_find}" ]]; then return 0; fi
        done
        return 1
    }

    __crt__args__get_tasks_not_in() {
        local these_tasks=${1}
        local other_tasks=()
        local i

        for (( i = 0; i < __crt__task_count; i++ )); do
            __crt__args__is_item_in_array "${i}" "${these_tasks}" || other_tasks=(${other_tasks[@]} ${i})
        done

        __crt__args__fn_result=("${other_tasks[@]}")
    }

    __crt__args__assign_sequential_prereqs() {
        local i
        for (( i = 1; i < __crt__task_count; i++ )); do
            declare -g -a "__crt__prereqs_${i}=($(( i - 1 )))"
        done
    }

    __crt__args__handle_task_flag() {
        set -- "${remaining_args[@]}"

        shift; (( $# )) || Error::Message "expected task name after '-'"
        __crt__names+=("${1}")
        shift; (( $# )) || Error::Message "expected command after task name"
        local args=()
        while (( $# )) && ! __crt__args__is_flag_starting_section "${1}"; do
            args+=("${1}")
            shift
        done
        declare -g -a "__crt__command_${__crt__task_count}=(\"\${args[@]}\")"
        __crt__pending+=("${__crt__task_count}")
        (( __crt__task_count++ )) || :

        remaining_args=("${@}")
    }

    __crt__args__handle_group_flag() {
        set -- "${remaining_args[@]}"
        shift
        __crt__groups+=("${__crt__task_count}")
        remaining_args=("${@}")
    }

    __crt__args__handle_sequential_flag() {
        set -- "${remaining_args[@]}"
        shift
        __crt__args__assign_sequential_prereqs
        remaining_args=("${@}")
    }

    __crt__args__handle_require_flag() {
        set -- "${remaining_args[@]}"

        local require
        local before

        while (( $# )) && __crt__args__is_require_flag "${1}"; do
            shift; (( $# )) || Error::Message "expected task name after '--require'"
            require=(${require[@]} $(__crt__name_index "${1}"))
            shift
        done

        if __crt__args__is_before_all_flag "${1}"; then
            shift
            __crt__args__get_tasks_not_in 'require'; before=("${__crt__args__fn_result[@]}")
            local b
            for b in "${before[@]}"; do
                declare -g -a "__crt__prereqs_${b}=(\${require[@]})"
            done
        elif __crt__args__is_before_flag "${1}"; then
            while (( $# )) && __crt__args__is_before_flag "${1}"; do
                shift; (( $# )) || Error::Message "expected task name after '--before'"
                before=$(__crt__name_index "${1}")
                shift
                if __crt__args__is_item_in_array "${before}" "require"; then
                    Error::Message "task cannot require itself"
                fi
                declare -g -a "__crt__prereqs_${before}=(\${__crt__prereqs_${before}[@]} \${require[@]})"
            done
        else
            Error::Message "expected '--before' or '--before-all' after '--require-all'"
        fi

        remaining_args=("${@}")
    }

    __crt__args__handle_require_all_flag() {
        set -- "${remaining_args[@]}"

        local require
        local before

        shift
        if __crt__args__is_before_all_flag "${1}"; then
            shift
            __crt__args__assign_sequential_prereqs  # --require-all --before-all is the same as --sequential
        elif __crt__args__is_before_flag "${1}"; then
            before=()
            while (( $# )) && __crt__args__is_before_flag "${1}"; do
                shift; (( $# )) || Error::Message "expected task name after '--before'"
                before=(${before[@]} $(__crt__name_index "${1}"))
                shift
            done
            __crt__args__get_tasks_not_in 'before'; require=("${__crt__args__fn_result[@]}")
            local b
            for b in "${before[@]}"; do
                declare -g -a "__crt__prereqs_${b}=(\${require[@]})"
            done
        else
            Error::Message "expected '--before' or '--before-all' after '--require-all'"
        fi

        remaining_args=("${@}")
    }

    __crt__args__resolve_group_prereqs() {
        local curr_index
        local task_index
        local curr_group
        local next_group
        local prev_group=0

        # All tasks in group N are prereqs for all tasks in group N+1. If N+1
        # does not exist, use the task count instead.
        for (( curr_index = 0; curr_index < ${#__crt__groups[@]}; curr_index++ )); do
            curr_group=${__crt__groups[${curr_index}]}
            next_group=${__crt__groups[$(( curr_index + 1 ))]:-${__crt__task_count}}
            for (( task_index = curr_group; task_index < next_group; task_index++ )); do
                declare -g -a "__crt__prereqs_${task_index}=(\${__crt__prereqs_${task_index}[@]} {${prev_group}..$(( curr_group - 1 ))})"
            done
            prev_group=${curr_group}
        done

        # No longer need this array up in our business.
        unset __crt__groups
    }

    __crt__args__ensure_no_requirement_loops() (
        # We will do a lightweight dry-run through all of the tasks and make sure we
        # do not get stuck anywhere.
        tasks_started=0

        is_task_allowed_to_start() {
            local task=${1}
            [[ -n "${__crt__pending[${task}]}" ]] || return 1
            local requires
            local prereqs="__crt__prereqs_${task}[@]"
            for requires in "${!prereqs}"; do
                [[ -z "${__crt__pending[${requires}]}" ]] || return 1
            done
        }

        start_allowed_tasks() {
            tasks_started=0
            local i
            for i in "${__crt__pending[@]}"; do
                if is_task_allowed_to_start "${i}"; then
                    start_task "${i}"
                    (( tasks_started++ )) || :
                fi
            done
        }

        start_task() {
            unset "__crt__pending[${1}]"
        }

        while true; do
            start_allowed_tasks
            [[ "${#__crt__pending[@]}" != 0 ]] || break
            [[ "${tasks_started}" -gt 0 ]] || Error::Message "detected requirement loop"
        done
    )

    __crt__args__parse() {
        local remaining_args=("${@}")

        while (( ${#remaining_args} )); do
            if __crt__args__is_task_flag "${remaining_args[0]}"; then
                __crt__args__handle_task_flag
            elif __crt__args__is_group_flag "${remaining_args[0]}"; then
                __crt__args__handle_group_flag
            elif __crt__args__is_require_flag "${remaining_args[0]}"; then
                __crt__args__handle_require_flag
            elif __crt__args__is_require_all_flag "${remaining_args[0]}"; then
                __crt__args__handle_require_all_flag
            elif __crt__args__is_sequential_flag "${remaining_args[0]}"; then
                __crt__args__handle_sequential_flag
            else
                Error::Message "unexpected argument '${remaining_args[0]}'"
            fi
        done

        __crt__args__resolve_group_prereqs
        __crt__args__ensure_no_requirement_loops
        __crt__unset 'args'
    }

    __crt__args__parse "${@}"

    #
    # Status Updates
    #

    __crt__txtred='\e[0;31m' # Red
    __crt__txtgrn='\e[0;32m' # Green
    __crt__txtylw='\e[0;33m' # Yellow
    __crt__txtblu='\e[0;34m' # Blue
    __crt__txtbld='\e[1m'    # Bold
    __crt__txtrst='\e[0m'    # Text Reset
    __crt__txtclr='\e[0K'    # Clear to end of line

    export CONCURRENT_COMPACT=${CONCURRENT_COMPACT:-0}

    __crt__use_compact_status() {
        [[ "${CONCURRENT_COMPACT}" != "0" || "${__crt__task_count}" -ge "$(tput lines)" ]]
    }

    if __crt__use_compact_status; then
        __crt__cols=$(tput cols)

        __crt__draw_meta       () { :; }
        __crt__start_animation () { :; }
        __crt__stop_animation  () { :; }
        __crt__print_failures  () { :; }

        __crt__draw_initial_tasks() {
            # task lines + most recent update lines + summary lines
            local rows=$(( __crt__task_count / __crt__cols + 4 ))
            local row
            for (( row = 0; row < rows; row++ )); do echo; done
            tput cuu "${rows}"
            tput sc
        }

        __crt__move_cursor_to_top() { tput rc ; }

        __crt__move_cursor_to_first_task() {
            __crt__move_cursor_to_top
            tput cud 2
        }

        __crt__requires_newline_after_tasks() {
            [[ $(( __crt__task_count % __crt__cols )) -ne 0 ]]
        }

        if __crt__requires_newline_after_tasks; then
            __crt__move_cursor_below_tasks() {
                __crt__move_cursor_to_index "${__crt__task_count}"
                echo
            }
        else
            __crt__move_cursor_below_tasks() {
                __crt__move_cursor_to_index "${__crt__task_count}"
            }
        fi

        __crt__move_cursor_below_status() {
            __crt__move_cursor_below_tasks
            echo
            tput el
            tput cuu 1
        }

        __crt__move_cursor_to_index() {
            local index=${1}
            local col=$(( index % __crt__cols ))
            local row=$(( index / __crt__cols ))
            __crt__move_cursor_to_first_task
            [[ "${col}" -eq 0 ]] || tput cuf "${col}"
            [[ "${row}" -eq 0 ]] || tput cud "${row}"
        }

        __crt__draw_status() {
            local index=${1}
            local code=${2}
            __crt__move_cursor_to_top
            __crt__draw_summary
            __crt__move_cursor_to_index "${index}"
            __crt__draw_task "${code}"
            __crt__move_cursor_below_tasks
            [[ "${code}" == "running" ]] || __crt__draw_recent_verbose_task "${index}" "${code}"
            __crt__move_cursor_to_top
        }

        __crt__draw_task() {
            local code=${1}
            if   [[ "${code}" == "int"     ]]; then printf "${__crt__txtred}%c${__crt__txtrst}" '!'
            elif [[ "${code}" == "skip"    ]]; then printf "${__crt__txtylw}%c${__crt__txtrst}" '-'
            elif [[ "${code}" == "running" ]]; then printf "${__crt__txtblu}%c${__crt__txtrst}" '>'
            elif [[ "${code}" == "0"       ]]; then printf '.'
            else                                    printf "${__crt__txtred}%c${__crt__txtrst}" 'X'
            fi
        }

        __crt__draw_recent_verbose_task() {
            local index=${1}
            local code=${2}
            local meta=${__crt__meta[${index}]}
            if   [[ "${code}" == "int"     ]]; then printf "\n ${__crt__txtred}%s${__crt__txtrst} " 'SIGINT'
            elif [[ "${code}" == "skip"    ]]; then printf "\n ${__crt__txtylw}%s${__crt__txtrst} " ' SKIP '
            elif [[ "${code}" == "0"       ]]; then printf "\n ${__crt__txtgrn}%s${__crt__txtrst} " '  OK  '
            else                                    printf "\n ${__crt__txtred}%s${__crt__txtrst} " 'FAILED'
            fi
            printf "%s" "${__crt__names[${index}]}"
            if [[ -n "${meta}" ]]; then printf " ${__crt__txtbld}%s${__crt__txtrst}" "${meta}"
            fi
            tput el  # clear to the end of the line in case the task previously displayed was longer
        }

        __crt__draw_summary() {
            local percent=$(( ${#__crt__codes[@]} * 100 / __crt__task_count ))
            local success="  ${__crt__success_task_count} passed"
            local failure
            local skipped
            local interrupted
            [[ "${__crt__failure_task_count}"     -eq 0 ]] || failure="  ${__crt__failure_task_count} failed"
            [[ "${__crt__skipped_task_count}"     -eq 0 ]] || skipped="  ${__crt__skipped_task_count} skipped"
            [[ "${__crt__interrupted_task_count}" -eq 0 ]] || interrupted="  ${__crt__interrupted_task_count} interrupted"
            printf " %3d%% %s%s%s%s\n\n" \
                "${percent}" \
                "${success}" \
                "${failure}" \
                "${skipped}" \
                "${interrupted}"
        }
    else
        __crt__seconds_between_frames=1.0
        __crt__running_status_current_frame=0
        __crt__running_status_frames=(
            " ${__crt__txtblu}    =>${__crt__txtrst} "
            " ${__crt__txtblu}     >${__crt__txtrst} "
        )

        __crt__move_cursor_to_top() {
            tput cuu "${__crt__task_count}"
            tput sc
        }

        __crt__move_cursor_below_tasks() {
            tput cud "${__crt__task_count}"
            tput sc
        }

        __crt__move_cursor_below_status() {
            __crt__move_cursor_below_tasks
        }

        __crt__draw_initial_tasks() {
            local i
            for (( i = 0; i < __crt__task_count; i++ )); do
                echo "        ${__crt__names[${i}]}"
            done
        }

        __crt__move_cursor_to_index() {
            local index=${1}
            [[ "${index}" -eq 0 ]] || tput cud "${index}"
        }

        __crt__draw_status() {
            local index=${1}
            local code=${2}
            tput rc
            __crt__move_cursor_to_index "${index}"
            __crt__draw_task "${code}"
            tput rc
        }

        __crt__draw_task() {
            local code=${1}
            if   [[ "${code}" == "running" ]]; then __crt__draw_running_status
            elif [[ "${code}" == "int"     ]]; then printf " ${__crt__txtred}%s${__crt__txtrst} " 'SIGINT'
            elif [[ "${code}" == "skip"    ]]; then printf " ${__crt__txtylw}%s${__crt__txtrst} " ' SKIP '
            elif [[ "${code}" == "0"       ]]; then printf " ${__crt__txtgrn}%s${__crt__txtrst} " '  OK  '
            else                                    printf " ${__crt__txtred}%s${__crt__txtrst} " 'FAILED'
            fi
        }

        __crt__draw_running_status() {
            # shellcheck disable=SC2059
            printf "${__crt__running_status_frames[${__crt__running_status_current_frame}]}"
        }

        __crt__draw_meta() {
            local index=${1}
            tput rc
            __crt__move_cursor_to_index "${index}"
            tput cuf 8  # move past status
            printf "%s ${__crt__txtbld}%s${__crt__txtrst}${__crt__txtclr}" "${__crt__names[${index}]}" "${__crt__meta[${index}]}"
            tput rc
        }

        __crt__update_running_status_frames() {
            local i
            for (( i = 0; i < __crt__task_count; i++ )); do
                if __crt__is_task_running "${i}"; then
                    __crt__draw_status "${i}" running
                fi
            done
            __crt__running_status_current_frame=$((
                (__crt__running_status_current_frame + 1) % ${#__crt__running_status_frames[@]}
            ))
        }

        __crt__indent() { sed 's/^/    /' "${@}" ; }

        __crt__print_failures() {
            cd "${__crt__status_dir}"
            local i
            for (( i = 0; i < __crt__task_count; i++ )); do
                if [[ "${__crt__codes[${i}]}" != '0' ]]; then
                    printf "\n['%s' failed with exit status %s]\n" "${__crt__names[${i}]}" "${__crt__codes[${i}]}"
                    __crt__indent "${i}"
                fi
            done
        }
    fi

    __crt__print_log_location() {
        if [[ "${__crt__final_status}" != "0" && "${CONCURRENT_DEPTH}" -eq 0 ]]; then
            printf '\nLogs for all tasks can be found in:\n    %s\n' "${CONCURRENT_LOG_DIR}/"
        fi
    }

    # Disable local echo so the user can't mess up the pretty display.
    __crt__disable_echo() { stty -echo 2>/dev/null || true ; }

    # Enable local echo so user can type again. (Simply exiting the subshell
    # is not sufficient to reset this, which is surprising.)
    __crt__enable_echo() { stty echo ; }

    __crt__hide_cursor() { tput civis ; }

    __crt__show_cursor() { tput cnorm ; }

    __crt__status_cleanup() {
        trap -- - INT  # no longer need special sigint handling
        __crt__move_cursor_below_status
        __crt__print_failures
        __crt__print_log_location
    }

    #
    # Signal Handling/General Cleanup
    #

    __crt__exit_by_signal() {
        # Proper sigint handling: http://www.cons.org/cracauer/sigint.html
        local signal=${1}
        # shellcheck disable=SC2064
        trap -- - "${signal}"    # reset the signal
        kill "-${signal}" -- $$  # re-raise the signal
        exit 255                 # don't resume the script
    }

    __crt__handle_exit() {
        rm -rf "${__crt__status_dir}"
        __crt__hide_failure __crt__restore_stdin_stream
        __crt__hide_failure __crt__enable_echo
        __crt__hide_failure __crt__show_cursor
    }

    __crt__handle_sigint() {
        CONCURRENT_LIMIT=-1
        __crt__interrupted=1
        __crt__clear_event_pipe
        __crt__cleanup_event_loop
        __crt__mark_all_running_tasks_as_interrupted
        __crt__run_event_loop
        __crt__status_cleanup
        __crt__stop_animation
        __crt__hide_failure wait
        __crt__exit_by_signal INT
    }

    # Keep track of how far we're nested inside concurrent instances.
    export CONCURRENT_DEPTH=${CONCURRENT_DEPTH:--1}
    (( CONCURRENT_DEPTH++ )) || :

    if [[ "${CONCURRENT_DEPTH}" -gt 0 ]]; then
        # If we're nested inside a running instance of concurrent, disable the
        # interactive statuses.
        __crt__enable_echo               () { :; }
        __crt__disable_echo              () { :; }
        __crt__draw_initial_tasks        () { :; }
        __crt__move_cursor_to_top        () { :; }
        __crt__move_cursor_below_status  () { :; }
        __crt__draw_status               () { :; }
        __crt__draw_meta                 () { :; }
        __crt__start_animation           () { :; }
        __crt__stop_animation            () { :; }
    fi

    export CONCURRENT_LOG_DIR=${CONCURRENT_LOG_DIR:-${PWD}/.logs/$(date +'%F@%T')}
    #mkdir -p "${CONCURRENT_LOG_DIR}"

    __crt__disable_echo || Error::Message 'Must be run in the foreground of an interactive shell!'
    __crt__status_dir=$(mktemp -d "${TMPDIR:-/tmp}/concurrent.lib.sh.XXXXXXXXXXX")
    __crt__event_pipe="${__crt__status_dir}/event-pipe"
    __crt__clear_event_pipe

    trap -- __crt__handle_exit EXIT
    trap -- __crt__handle_sigint INT

    __crt__hide_cursor
    __crt__start_all_tasks
    __crt__wait_for_all_tasks
    __crt__show_cursor

    exit ${__crt__final_status}
)

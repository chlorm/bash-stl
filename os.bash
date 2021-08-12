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

# dirname
# ln
# lsb_release (optional)
# mkdir
# readlink
# rm
# touch
# uname (optional)
# unlink

stl_os_abspath_resolve() {
    stl_func_reqargs '1' "$#"
    local -r path="$1"

    readlink -f "$(readlink -f "$(dirname "$(readlink -f "$path")")")"
}

stl_os_link() {
    stl_func_reqargs '2' "$#"
    stl_dir_create "$(command dirname "$2")"
    command ln "$1" "$2"
}

stl_os_makedir() {
    stl_func_reqargs '1' "$#"
    # Make sure directory is not a symlink
    if [ -L "$1" ]; then
        command unlink "$1" 1>&2
    fi
    if [ ! -d "$1" ]; then
        command mkdir "$1" 1>&2
    fi
}

stl_os_makedirs() {
    stl_func_reqargs '1' "$#"
    # Make sure directory is not a symlink
    if [ -L "$1" ]; then
        command unlink "$1" 1>&2
    fi
    if [ ! -d "$1" ]; then
        command mkdir --parents "$1" 1>&2
    fi
}

stl_os_remove() {
    stl_func_reqargs '1' "$#"
    # Make sure file is not a symlink
    if [ -L "$1" ]; then
        command unlink "$1" 1>&2
    fi
    if [ -f "$1" ]; then
        command rm -f "$1" 1>&2
    fi
}

stl_os_removedirs() {
    stl_func_reqargs '1' "$#"
    # Make sure directory is not a symlink
    if [ -L "$1" ]; then
        command unlink "$1" 1>&2
    fi
    if [ -d "$1" ]; then
        command rm -fr "$1" 1>&2
    fi
}

stl_os_symlink() {
    stl_func_reqargs '2' "$#"
    stl_dir_create "$(command dirname "$2")"
    # Ignore if a symlink already exists and points to the correct location.
    if [ "$(command readlink -f "$2")" != "$1" ]; then
        stl_os_removedirs "$2"
        [ -e "$1" ]
        command ln -s "$1" "$2"
    fi
}

stl_os_touch() {
    stl_func_reqargs '1' "$#"
    # Make sure file is not a symlink
    if [ -L "$1" ]; then
        command unlink "$1" 1>&2
    fi
    if [ ! -f "$1" ]; then
        command touch "$1" 1>&2
    fi
}

stl_os_user() { $(command id -u); }

# Determine if the user is root
stl_os_user_root() { [ $(stl_os_user) -eq 0 ]; }

# Find host os kernel
# shellcheck disable=SC2120
stl_os_platform() {
    stl_func_reqargs '0' "$#"
    local Kernel
    local KernelStrings
    local -a ProcVersion=()
    local Uname

    mapfile -t ProcVersion <${ROOT:-}/proc/version 2>&-
    Uname="$(command uname -s 2>&-)"

    # $ProcVersion must come first to correctly detect MS Win Sub Linux
    KernelStrings="${ProcVersion[*]} $OSTYPE $Uname"

    shopt -s nocasematch
    case "$KernelStrings" in
    *linux*)
        Kernel="linux"
        ;;
    *freebsd*)
        Kernel="freebsd"
        ;;
    *solaris*)
        Kernel="solaris"
        ;;
    *microsoft*)
        # Microsoft Windows Subsystem for Linux
        Kernel="windows"
        ;;
    *cygwin*)
        Kernel="cygwin"
        ;;
    *darwin*)
        Kernel="darwin"
        ;;
    *)
        # FIXME:
        Kernel=
        ;;
    esac
    shopt -u nocasematch

    stl_type_str "$Kernel"

    echo "$Kernel"
}

# Take first result of linux os name match
stl_os_platform_linux() {
    stl_func_reqargs '0' "$#"
    [ "$(stl_os_platform)" == 'linux' ]

    local -a etcRelease=()
    local -a tmp=()
    local distro
    local distroStrings

    # Find linux distro via /etc/*-release
    for i in ${ROOT:-}/etc/*-release; do
        tmp=()
        mapfile -t tmp <$i
        etcRelease+=("${tmp[@]}")
    done
    distroStrings="${etcRelease[*]}"
    # Find linux distro via linux standard base
    if stl_path_check 'lsb_release'; then
        distroStrings="$distroStrings $(command lsb_release -a 2>&-)"
    fi
    # Find linux distro via uname -a
    if stl_path_check 'uname'; then
        distroStrings="$distroStrings $(command uname -a 2>&-)"
    fi

    shopt -s nocasematch
    case "$distroStrings" in
    *arch*)
        distro="arch"
        ;;
    *centos*)
        distro="centos"
        ;;
    *debian*)
        distro="debian"
        ;;
    *fedora*)
        distro="fedora"
        ;;
    *gentoo*)
        distro="gentoo"
        ;;
    *nixos*)
        distro="nixos"
        ;;
    *opensuse*)
        distro="opensuse"
        ;;
    *'red hat'*)
        distro="red hat"
        ;;
    *slackware*)
        distro="slackware"
        ;;
    *suse*)
        distro="suse"
        ;;
    *triton*)
        distro="triton"
        ;;
    *ubuntu*)
        distro="ubuntu"
        ;;
    *)
        # FIXME:
        distro=
        ;;
    esac
    shopt -u nocasematch

    stl_type_str "$distro"

    echo "$distro"
}

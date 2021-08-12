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

# lscpu

# FIXME: drop usage of lscpu, parse cpuinfo flags instead
# Return CPU architecture without endianness or address space size
# shellcheck disable=SC2120
stl_cpu_arch() {
    #stl_func_reqargs '0' "$#"
    # Do NOT use `uname -m' to achieve this functionality.
    local arch
    local -a cpuinfo=()
    local i
    local -a cpuFlags=()

    mapfile -t cpuinfo < <(command lscpu)
    for i in "${cpuinfo[@]}"; do
        if [[ $i =~ ^'Architecture:' ]]; then
            arch="$i"
            break
        fi
    done

    shopt -s nocasematch
    case "$arch" in
    *i686* | *x86_64*)
        arch='x86'
        ;;
    *power*)
        arch='power'
        ;;
    *arm*)
        arch='arm'
        ;;
    *)
        # Null variable to return error
        arch=
        ;;
    esac
    shopt -u nocasematch

    # FIXME: implement better error message here
    stl_type_str "$arch"

    echo "$arch"
}

# Find CPU address space size (ie. 32bit/64bit)
stl_cpu_address_space() {
    stl_func_reqargs '0' "$#"
    local addressSpace=32
    local cpuFlags
    local -a cpuinfo=()
    local -r prefix='flags'
    local i

    mapfile -t cpuinfo </proc/cpuinfo
    for i in "${cpuinfo[@]}"; do
        if [[ $i =~ ^'flags' ]]; then
            cpuFlags="$i"
            break
        fi
    done
    if [[ "$cpuFlags" == *' lm '* ]]; then
        addressSpace=64
    fi

    stl_type_int "$addressSpace"

    echo "$addressSpace"
}

# shellcheck disable=SC2120
stl_cpu_sockets() {
    stl_func_reqargs '0' "$#"
    local i
    local -a cpuinfo=()
    local sockets

    mapfile -t cpuinfo </proc/cpuinfo
    for i in "${cpuinfo[@]}"; do
        if [[ $i =~ ^'Socket(s):' ]]; then
            sockets="$i"
            break
        fi
    done
    sockets=${sockets//[^0-9]/}

    if [ ! $sockets -ge 1 ]; then
        # Assume a socket exists even if it fails to find any
        sockets=1
    fi

    echo "$sockets"
}

# FIXME: needs testing for big/little, currently assumes all sockets identical
# shellcheck disable=SC2120
stl_cpu_cores() {
    stl_func_reqargs '0' "$#"
    local i
    local cores
    local -a cpuinfo=()

    mapfile -t cpuinfo </proc/cpuinfo
    for i in "${cpuinfo[@]}"; do
        if [[ $i =~ ^'Core(s) per socket:' ]]; then
            cores="$i"
            break
        fi
    done
    cores=${cores//[^0-9]/}

    if [ -z "$cores" ]; then
        cores=1
    else
        cores=$(($cores * $(stl_cpu_sockets)))
    fi

    echo "$cores"
}

stl_cpu_logical() {
    stl_func_reqargs '0' "$#"
    # Assumes all sockets are identical, only some arm platforms won't
    # work with this logic

    local i
    local CpuThreads
    local -a cpuinfo=()

    # Finds number of logical threads per physical core
    mapfile -t cpuinfo </proc/cpuinfo
    for i in "${cpuinfo[@]}"; do
        if [[ $i =~ ^'Thread(s) per core:' ]]; then
            CpuThreads="$i"
            break
        fi
    done
    CpuThreads=${CpuThreads//[^0-9]/}
    if stl_type_int $CpuThreads 2>&-; then
        # Convert to number of threads per cpu
        CpuThreads=$(($CpuThreads * $(stl_cpu_physical)))
    fi

    CpuThreads=${CpuThreads//[^0-9]/}

    if stl_type_null $CpuThreads 2>&-; then
        CpuThreads=$(stl_cpu_physical)
    else
        CpuThreads=$(($CpuThreads * $(stl_cpu_sockets)))
    fi

    echo "$CpuThreads"
}

stl_cpu_flags() {
    stl_func_reqargs '0' "$#"
    local -a cpuinfo=()
    local i
    local cpuFlags=
    local prefix='flags'

    if [ "$(stl_cpu_arch)" == 'arm' ]; then
        prefix='Features'
    fi

    mapfile -t cpuinfo </proc/cpuinfo
    for i in "${cpuinfo[@]}"; do
        if [[ $i =~ ^$prefix ]]; then
            cpuFlags="$i"
            break
        fi
    done
    # Split out the flags: prefix
    mapfile -t -d: cpuinfo < <(printf '%s\n' "$cpuFlags")
    # Split the idividual flags
    mapfile -t -d' ' cpuinfo < <(echo "${cpuinfo[1]}")
    for i in "${cpuinfo[@]}"; do
        if [ stl_type_str "$i" ] 2>&-; then
            printf '%s\n' "${i//[$'\t\r\n']/}"
        fi
    done
}

stl_cpu_x86_level() {
    stl_func_reqargs '0' "$#"
    local -A levels=(
        [1]='cmov,cx8,fpu,fxsr,mmx,lm,sse2,syscall'
        [2]='cx16,lahf_lm,popcnt,sse4_1,sse4_2,ssse3'
        [3]='avx512bw,avx512cd,avx512dq,avx512f,avx512vl'
    )
    local -a cpuFlags=()
    local l
    local r
    local -i level=0

    mapfile -t cpuFlags < <(stl_cpu_flags)
    for l in 1 2 3; do
        mapfile -t -d, reqs < <(printf '%s' "${levels[$l]}")
        for r in "${reqs[@]}"; do
            if ! stl_list_contains "$r" "${cpuFlags[@]}"; then
                echo $level
                return 0
            fi
        done
        level=$(($level + 1))
    done
}

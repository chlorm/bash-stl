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

# While this is intended for symantic versioning, it will work on integer, or
# any period separated integer based version formats similiar to symver.
stl_symver_impl() {
    stl_func_reqargs '2' "$#"
    if [ "$1" == "$2" ]; then
        echo 'eq'
        return 0
    fi
    local -i i
    local -a ver1=()
    local -a ver2=()

    mapfile -t -d. ver1 < <(printf '%s' "$1")
    mapfile -t -d. ver2 < <(printf '%s' "$2")

    # fill empty fields in ver1 with zeros
    for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i = 0; i < ${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        elif ((10#${ver1[i]} > 10#${ver2[i]})); then
            echo 'gt'
            return 0
        elif ((10#${ver1[i]} < 10#${ver2[i]})); then
            echo 'lt'
            return 0
        fi
    done
    stl_log_error 'version comparison failed'
    return 1
}
stl_symver_atleast() { [[ "$(stl_symver_impl "$1" "$2")" == @('eq'|'gt') ]]; }
stl_symver_nomore() { [[ "$(stl_symver_impl "$1" "$2")" == @('eq'|'lt') ]]; }
stl_symver_greater() { [[ "$(stl_symver_impl "$1" "$2")" == 'gt' ]]; }
stl_symver_lesser() { [[ "$(stl_symver_impl "$1" "$2")" == 'lt' ]]; }

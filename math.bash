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

# sort
# uniq

stl_math_mode() {
    STL_FUNC_OVERLOAD=1 stl_func_reqargs '1' "$#"
    local -a i=()
    local -r count="${STL_MATH_MODE_COUNT:-}"

    # shellcheck disable=SC2207
    i=($(
        printf '%s\n' "$@" |
            # Remove duplicates
            command uniq -c |
            # Sort the most common first
            command sort -n -k 1 -r
    ))

    if stl_type_str "$count" 2>&-; then
        echo "${i[0]}"
    else
        echo "${i[1]}"
    fi
}

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

# grep
# readlink

# Add direcory to $PATH
# FIXME: convert to pure bash
stl_path_add() {
    stl_func_reqargs '1' "$#"
    [ -d "$1" ]
    if [ -z "$(echo "$PATH" | command grep "$1" 2>&-)" ]; then
        export PATH="$PATH:$1"
    fi
}

# Remove directory from $PATH
stl_path_remove() {
    stl_func_reqargs '1' "$#"
    local -a paths=()
    local -a final=()
    local path

    mapfile -t -d: paths < <(printf '%s' "$PATH")

    for path in "${paths[@]}"; do
        if [[ ! "$path" =~ ^$1 ]]; then
            final+=("$path")
        fi
    done

    IFS=\: eval 'PATH="${final[*]}"'
    export PATH
}

# Finds the path to the binary
stl_path_bin() {
    stl_func_reqargs '1' "$#"
    type -P "$1"
}

# Resolves the absolute path of a binary
stl_path_bin_abs() {
    stl_func_reqargs '1' "$#"
    local -a paths=()
    local path

    mapfile -t -d: paths < <(printf '%s' "$PATH")

    for path in "${paths[@]}"; do
        path="$(command readlink -f "$path/$1")"
        if test -e "$path"; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# Test to see if a binary exists in PATH
stl_path_has() {
    stl_func_reqargs '1' "$#"
    type "$1" >/dev/null 2>&1
}

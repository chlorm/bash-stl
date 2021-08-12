# Copyright (c) 2014-2016, Cody Opel <cwopel@chlorm.net>
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

# bc

stl_conv_float_to_int() {
    stl_func_reqargs '1' "$#"
    local -r float="$1"
    local floatRounded

    # Make sure not to fail if num is already an integer
    if stl_type_int "$float" 2>&-; then
        echo "$float"
        return 0
    fi

    stl_type_float "$float"

    # Rounds float to the nearest whole number
    # shellcheck disable=SC2046
    floatRounded=$(printf '%.0f' $(echo "$float" | command bc -l))

    echo "$floatRounded"
}

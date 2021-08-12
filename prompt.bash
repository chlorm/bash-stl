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

stl_prompt_password() {
    stl_func_reqargs '0' "$#"
    local Pass1 Pass2

    while true; do
        read -r -s -p "Password: " Pass1
        echo
        read -r -s -p "Confirm: " Pass2
        echo
        if [ "$Pass1" == "$Pass2" ]; then
            break
        fi
        stl_log_warn 'passwords do not match, try again'
    done

    echo "$Pass1" >/dev/null 2>&1
}

# Ask a yes or no question
stl_prompt_y_or_n() {
    stl_func_reqargs '2' "$#"
    local Answer
    local -i Default=2
    local Prompt

    case "$2" in
    '')
        Default=2
        Prompt='(y/n)'
        ;;
    'y')
        Default=0
        Prompt='(Y/n)'
        ;;
    'n')
        Default=1
        Prompt='(y/N)'
        ;;
    *)
        Default=2
        Prompt='(y/n)'
        ;;
    esac

    while true; do
        read -r -p "$1 $Prompt: " Answer
        case "$(stl_str_lower "$Answer")" in
        # FIXME: don't return error code (using errexit)
        '') [ ! $Default -eq 2 ] && return $Default ;;
        'y' | 'yes') break && return 0 ;;
        'n' | 'no') break && return 1 ;;
        esac
        echo "Response must be y/n or yes/no, try again"
    done

    return 2
}

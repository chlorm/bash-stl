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

# mktemp
# sed

# FIXME: add support for using arrays instead of variables (prepend/append)
# FIXME: add required boolean (if flag must be passed)

# Options:
# short       - 'short=<flag>' (e.g. -f)
# long        - 'long=<flag>' (e.g. --flag)
# description - 'desc=<description>'
# default     - ''
# value       - ''
# variable    - ''
stl_arg_define() {
    [ $# -ge 3 ]

    for ((i = 1; i <= $#; i++)); do
        local option
        local -a kv=()
        local key
        local value

        eval option="\$$i"
        mapfile -t -d= kv < <(echo "$option")
        key="${kv[0]}"
        value="${kv[1]}"

        stl_type_str "$key"
        stl_type_str "$value"

        case "$key" in
        'default') local default="$value" ;;
        'desc') local desc="$value" ;;
        'long')
            [ ${#value} -gt 1 ]
            local long="--$value"
            ;;
        'short')
            [ ${#value} -eq 1 ]
            local shortname="$value"
            local short="-$shortname"
            ;;
        'value') local val="$value" ;;
        'variable') local variable="$value" ;;
        'boolean') local boolean="$value" ;;
        esac
    done

    stl_type_str "${variable+x}"
    stl_type_str "$long"

    # Usage message
    ArgsUsage="$ArgsUsage${ArgsUsage:+#NL}    $short $(printf '%-12s %s' "$long:" "$desc")${default:+ [default:$default]}"
    # Translate long options to short options
    ArgsCaseStatements="$ArgsCaseStatements#NL#TB#TB$long)#NL#TB#TB#TBparams=\"\$params $short\";;"

    # Default
    if [ -n "${default}" ]; then
        ArgDefaults="$ArgDefaults#NL$variable=$default"
    fi

    stl_args_req_input() {
        if stl_type_null "$boolean" 2>&- && stl_type_str "$variable" 2>&-; then
            echo ":"
        fi
    }

    # GetOpts arguments
    GetOptsArgumentString="$GetOptsArgumentString $shortname$(stl_args_req_input)"
    GetOptsCaseStatements="$GetOptsCaseStatements#NL$shortname)#NL$variable=\"\$OPTARG\";;"
}

# FIXME: if long flag is used return long flag in error message
# FIXME: throw an error if both the short & long flag are used
# FIXME: fix parsing of input with spaces
stl_args_build() {
    local ArgFile
    local Name
    local -A ReplaceChars
    local TMPDIR

    Name="$(stl_program_name)"
    ArgFile="$(command mktemp)"

    # Building getopts header here

    # Function usage
    command cat <<EOF >"$ArgFile"
local params param arg

function ${Name}_usage(){
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

  case "\${param}" in
    ${ArgsCaseStatements}
    '-h'|'--help')
      ${Name}_usage
      exit 0
      ;;
    *)
      if [[ "\${param}" == --* ]] ; then
        echo -e "Unrecognized option: \${param}"
        ${Name}_usage
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
  case "\$arg" in
    # Substitute actions for different variables
    ${GetOptsCaseStatements}
    :) stl_log_error "Option \\\`-\$OPTARG' requires an argument" 'stl_args_build' ; exit 1 ;;
    *) ${Name}_usage ; exit 1 ;;
  esac
done

# Clean up after self
command rm "${ArgFile}"

EOF

    ReplaceChars=(['#NL']='\n' ['#TB']='\t')

    for i in "${!ReplaceChars[@]}"; do
        # FIXME: convert to pure bash
        command sed -i "$ArgFile" \
            -e "s/$i/${ReplaceChars[$i]}/g"
    done

    # Unset global variables
    unset ArgsUsage
    unset ArgsCaseStatements
    unset GetOptsCaseStatements
    unset GetOptsArgumentString
    unset ArgDefaults

    # Return file name to parent
    echo "$ArgFile"
}

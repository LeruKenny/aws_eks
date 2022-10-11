#!/bin/bash
# Terraform Scaffold
#
# A wrapper for running terraform projects
# - handles remote state
# - uses consistent .tfvars files for each environment

##
# Set Script Version
##
readonly script_ver="1.7.0";

##
# Standardised failure function
##
function error_and_die {
  echo -e "ERROR: ${1}" >&2;
  exit 1;
};

##
# Print Script Version
##
function version() {
  echo "${script_ver}";
}

##
# Print Usage Text
##
function usage() {

cat <<EOF
Usage: ${0} \\
  -a/--action        [action] \\
  -b/--bucket-prefix [bucket_prefix] \\
  -c/--component     [component_name] \\
  -e/--environment   [environment] \\
  -g/--group         [group]
  -i/--build-id      [build_id] (optional) \\
  -p/--project       [project] \\
  -r/--region        [region] \\
  -d/--detailed-exitcode \\
  -n/--no-color \\
  -w/--compact-warnings \\
  -- \\
  <additional arguments to forward to the terraform binary call>
action:
 - Special actions:
    * plan / plan-destroy
    * apply / destroy
    * graph
    * taint / untaint
    * shell
- Generic actions:
    * See https://www.terraform.io/docs/commands/
bucket_prefix (optional):
 Defaults to: "\${project_name}-tfscaffold"
 - myproject-terraform
 - terraform-yourproject
 - my-first-tfscaffold-project
build_id (optional):
 - testing
 - \$BUILD_ID (jenkins)
component_name:
 - the name of the terraform component module in the components directory
environment:
 - dev
 - test
 - prod
 - management
group:
 - dev
 - live
 - mytestgroup
project:
 - The name of the project being deployed
region (optional):
 Defaults to value of \$AWS_DEFAULT_REGION
 - the AWS region name unique to all components and terraform processes
detailed-exitcode (optional):
 When not provided, false.
 Changes the plan operation to exit 0 only when there are no changes.
 Will be ignored for actions other than plan.
no-color (optional):
 Append -no-color to all terraform calls
compact-warnings (optional):
 Append -compact-warnings to all terraform calls
additional arguments:
 Any arguments provided after "--" will be passed directly to terraform as its own arguments
EOF
};

##
# Test for GNU getopt
##
getopt_out=$(getopt -T)
if (( $? != 4 )) && [[ -n $getopt_out ]]; then
  error_and_die "Non GNU getopt detected. If you're using a Mac then try \"brew install gnu-getopt\"";
fi

##
# Execute getopt and process script arguments
##
readonly raw_arguments="${*}";
ARGS=$(getopt \
         -o dhnvwa:b:c:e:g:i:p:r: \
         -l "help,version,bootstrap,action:,bucket-prefix:,build-id:,component:,environment:,group:,project:,region:,detailed-exitcode,no-color,compact-warnings" \
         -n "${0}" \
         -- \
         "$@");

#Bad arguments
if [ $? -ne 0 ]; then
  usage;
  error_and_die "command line argument parse failure";
fi;

eval set -- "${ARGS}";

declare bootstrap="false";
declare component_arg;
declare environment_arg;
declare group;
declare action;
declare project;
declare detailed_exitcode;
declare no_color;
declare compact_warnings;

while true; do
  case "${1}" in
    -h|--help)
      usage;
      exit 0;
      ;;
    -v|--version)
      version;
      exit 0;
      ;;
    -c|--component)
      shift;
      if [ -n "${1}" ]; then
        component_arg="${1}";
        shift;
      fi;
      ;;
    -e|--environment)
      shift;
      if [ -n "${1}" ]; then
        environment_arg="${1}";
        shift;
      fi;
      ;;
    -g|--group)
      shift;
      if [ -n "${1}" ]; then
        group="${1}";
        shift;
      fi;
      ;;
    -a|--action)
      shift;
      if [ -n "${1}" ]; then
        action="${1}";
        shift;
      fi;
      ;;
    -p|--project)
      shift;
      if [ -n "${1}" ]; then
        project="${1}";
        shift;
      fi;
      ;;
    --bootstrap)
      shift;
      bootstrap="true";
      ;;
    -d|--detailed-exitcode)
      shift;
      detailed_exitcode="true";
      ;;
    -n|--no-color)
      shift;
      no_color="-no-color";
      ;;
    -w|--compact-warnings)
      shift;
      compact_warnings="-compact-warnings";
      ;;
    --)
      shift;
      break;
      ;;
  esac;
done;

declare extra_args="${@} ${no_color} ${compact_warnings}"; # All arguments supplied after "--"

##
# Script Set-Up
##

# Determine where I am and from that derive basepath and project name
script_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
base_path="${script_path%%\/bin}";
project_name_default="${base_path##*\/}";

status=0;

echo "Args ${raw_arguments}";

# Ensure script console output is separated by blank line at top and bottom to improve readability
trap echo EXIT;
echo;

##
# Munge Params
##

# Bootstrapping is special
if [ "${bootstrap}" == "true" ]; then
  [ -n "${component_arg}" ] \
    && error_and_die "The --bootstrap parameter and the -c/--component parameter are mutually exclusive";
  [ -n "${build_id}" ] \
    && error_and_die "The --bootstrap parameter and the -i/--build-id parameter are mutually exclusive. We do not currently support plan files for bootstrap";
else
  # Validate component to work with
  [ -n "${component_arg}" ] \
    || error_and_die "Required argument missing: -c/--component";
  readonly component="${component_arg}";

  # Validate environment to work with
  [ -n "${environment_arg}" ] \
    || error_and_die "Required argument missing: -e/--environment";
  readonly environment="${environment_arg}";
fi;

[ -n "${action}" ] \
  || error_and_die "Required argument missing: -a/--action";

declare component_path;
if [ "${bootstrap}" == "true" ]; then
  component_path="${base_path}/bootstrap";
else
  component_path="${base_path}/components/${component}";
fi;

# Get the absolute path to the component
if [[ "${component_path}" != /* ]]; then
  component_path="$(cd "$(pwd)/${component_path}" && pwd)";
else
  component_path="$(cd "${component_path}" && pwd)";
fi;

[ -d "${component_path}" ] || error_and_die "Component path ${component_path} does not exist";

## Debug
#echo $component_path;

##
# Begin parameter-dependent logic
##

case "${action}" in
  apply)
    refresh="-refresh=true";
    ;;
  destroy)
    destroy='-destroy';
    refresh="-refresh=true";
    ;;
  plan)
    refresh="-refresh=true";
    ;;
  plan-destroy)
    action="plan";
    destroy="-destroy";
    refresh="-refresh=true";
    ;;
  *)
    ;;
esac;

# Tell terraform to moderate its output to be a little
# more friendly to automation wrappers
# Value is irrelavant, just needs to be non-null
export TF_IN_AUTOMATION="true";

for rc_path in "${base_path}" "${base_path}/etc" "${component_path}"; do
  if [ -f "${rc_path}/.terraformrc" ]; then
    echo "Found .terraformrc at ${rc_path}/.terraformrc. Overriding.";
    export TF_CLI_CONFIG_FILE="${rc_path}/.terraformrc";
  fi;
done;

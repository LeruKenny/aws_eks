# eks_scaffolding script 
Usage: ${0} \\
  -a/--action        [action] \\
  -c/--component     [component_name] \\
  -e/--environment   [environment] \\
  -p/--project       [project] \\
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

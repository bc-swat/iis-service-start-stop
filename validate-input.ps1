Param(
    [parameter(Mandatory = $true)]
    [string]$action
)

$action_lower = $action.ToLower()
$available_actions = @( "start", "stop", "restart" )

if($available_actions -notcontains $action){
    Write-Host "$action not in available list of actions"
    exit 1
}

exit 0
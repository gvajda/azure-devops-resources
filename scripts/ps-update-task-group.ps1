<#
.SYNOPSIS

Update an Azure DevOps Task group via the Azure REST API

.DESCRIPTION

Update an Azure DevOps Task group via the Azure REST API. Intended to use in Azure DevOps Release pipelines (the parameter default values and example command are using Azure DevOps built in variables - the parameters may need to be passed to the script dependending on how the script is set up in the pipeline).

.PARAMETER SecretToken
OAuth token to send in the REST API request authorization header. Default value refers to the Azure DevOps agent's built in access token.

.PARAMETER TeamFoundationCollectionUri
Uri to Azure DevOps containing the organization name where the Task group takes place. Example value: https://dev.azure.com/fabrikamfiber/

.PARAMETER TeamProject
Azure DevOps containing the project name where the Task group takes place.

.PARAMETER TaskGroupTemplatePath
File path of the Task group JSON.

.INPUTS

None. You cannot pipe objects to ps-update-task-group.ps1.

.OUTPUTS

None. ps-update-task-group.ps1 does not generate any output.

.EXAMPLE

PS> .\ps-update-task-group.ps1  -TaskGroupTemplatePath $(System.DefaultWorkingDirectory)/**/buildartefactname/subfolders/exported-and-updated-task-group.json

.LINK
https://docs.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=classic#systemaccesstoken
#>

param (
    [string]$SecretToken = "$(System.AccessToken)",
    [string]$TeamFoundationCollectionUri = "$(System.TeamFoundationCollectionUri)",
    [string]$TeamProject = "$(System.TeamProject)",
    [string]$TaskGroupTemplatePath
)

Write-Host "Initialize authentication context"
$token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f '', $SecretToken)))
$header = @{authorization = "Basic $token"}

Write-Host "Parsing $TaskGroupTemplatePath"
$TaskGroupTemplateFileName = Get-ChildItem -Path $TaskGroupTemplatePath | ForEach-Object{$_.FullName}
Write-Host "TaskGroupTemplateFileName: $TaskGroupTemplateFileName"
$TaskGroupTemplateFileContent = Get-Content $TaskGroupTemplateFileName
$TaskGroupJson = $TaskGroupTemplateFileContent | ConvertFrom-Json
$TaskGroupId = $TaskGroupJson.id
Write-Host "Task Group ID: $TaskGroupId"

$RestApiUrl = $TeamFoundationCollectionUri + $TeamProject + "/_apis/distributedtask/taskgroups/" + $TaskGroupId + "?api-version=5.1-preview.1"

Write-Host "Send REST update request - URL: $RestApiUrl"
Try {
	$Response = Invoke-WebRequest -Uri $RestApiUrl -Headers $header -Body $TaskGroupTemplateFileContent -Method Put -ErrorAction SilentlyContinue -ContentType "application/json"
	$StatusCode = $Response.StatusCode
	$StatusDescription = $Response.StatusDescription
	Write-Host "Response: $StatusCode - $StatusDescription"
	if($StatusCode -ne "200") {
		$Response.Content | ConvertFrom-Json | ConvertTo-Json | Write-Host
        Throw
	}
} Catch {
	$RestError = $_
	$ErrorText = $RestError.ToString()
	Try {
		$ErrorJson = $ErrorText | ConvertFrom-Json
		$ErrorText = $ErrorJson | ConvertTo-Json
	} Catch {
		Throw $RestError
	}
	
	Write-Host "##vso[task.logissue type=warning]`n$ErrorText"
	Write-Host "##vso[task.logissue type=warning]Task Group update failed"

    Throw $RestError
}

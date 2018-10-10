param($bookname,$target="archive")


$script:settingsFile = "$PSScriptRoot\settings.json"

function LoadSettings
{
	if( ! (Test-Path $script:settingsFile) )
	{
		@{
			"sourceEbooks" = "`$PSScriptRoot\storage\ebooks";
			"sourceKindle" = "`$(`$Env:UserProfile)\Documents\My Kindle Content\";
			"decryptedStorage" = "`$PSScriptRoot\storage\decryptedkindle";
			"library" = "`$PSScriptRoot\output\ebooks";
			"kindleLibrary" = "`$PSScriptRoot\output\ebooks";
			"publishFolder" = "`$PSScriptRoot\published";
		} | ConvertTo-Json | SC -Path $script:settingsFile
	}
	$script:settings = gc -Raw $script:settingsFile | ConvertFrom-Json
}

function GetSettingsPath
{
	param($key)
	
	$ExecutionContext.InvokeCommand.ExpandString($script:settings."$key") 
}

function NormalizePath
{
	param($path)
	if( !(Test-Path $path))
	{
		mkdir $path
	}
	Resolve-Path $path
}

$kindlelib = NormalizePath (GetSettingsPath "kindleLibrary")
$lib = NormalizePath (GetSettingsPath "library")

$result = @()
$result += ls "$kindlelib\$bookname*"
$result += ls "$lib\$bookname*"

$outfolder = GetSettingsPath "publishFolder"
if( Test-Path $outfolder )
{
	$result | select -Unique | ?{ !(Test-Path "$outfolder$target\$($_.Name)") } | %{
		Write-Host "Publishing $($_.Name) to $target"
		cp -Recurse -Force $_.FullName "$outfolder$target"
	}
}
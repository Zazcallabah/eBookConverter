#load settings file
#	path to dedrm
#		if missing, alert for https://github.com/apprenticeharper/DeDRM_tools/archive/master.zip
#	path to decrypted kindle storage
#	path to regular ebook storage
#	output folder for regular ebooks
#	output folder for kindle books
#	output folder for final library
#check for python
#check for calibre

function LoadSettings
{
	if( ! (Test-Path "$PSScriptRoot\settings.json") )
	{
		@{
			"decryptedkindle" = "`$PSScriptRoot\storage\decryptedkindle";
			"ebooks" = "`$PSScriptRoot\storage\ebooks";
			"outregular" = "`$PSScriptRoot\output\ebooks";
			"outkindle" = "`$PSScriptRoot\output\kindle";
			"publishfolder" = "`$PSScriptRoot\published";
		} | ConvertTo-Json | SC -Path "$PSScriptRoot\settings.json"
	}
	$script:settings = gc -Raw "$PSScriptRoot\settings.json" | ConvertFrom-Json
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

function GetDeDrmPath
{
	if( !(test-path "$PSScriptRoot\DeDRM_tools-master" ))
	{
		[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
		Invoke-WebRequest -Uri "https://github.com/apprenticeharper/DeDRM_tools/archive/master.zip" -OutFile "$PSScriptRoot\master.zip"
		expand-archive "$PSScriptRoot\master.zip" -DestinationPath "$PSScriptRoot"
	}
	$dedrmpath = ls DeDRM_tools-master -Recurse -Filter "DeDRM_App.pyw" | select -first 1 -ExpandProperty FullName
	if( $dedrmpath -eq $null )
	{
		throw "dedrm cant be found"
	}
	return $dedrmpath
}

function EnsurePython
{
	if( (get-command python -ErrorAction SilentlyContinue) -eq $null )
	{
		throw "python cant be found, please make sure python3 is installed and available on the path"
	}
}

function GetEbookConvert
{
	$ebookconvert =  ls calibre -Recurse -Filter "ebook-convert.exe" | select -first 1 -ExpandProperty FullName
		
	if( $ebookconvert -eq $null )
	{
		throw "calibre cant be found, please install calibre-portable into the calibre folder"
	}
	return $ebookconvert
}

function EnsureKindleApp
{
	if(!(test-path "$($env:LOCALAPPDATA)\Amazon\Kindle\application\"))
	{
		write-warning "Kindle app not installed. Use the installer provided to install kindle."
	}
	if( test-path "$($env:LOCALAPPDATA)\Amazon\Kindle\application\renderer-test.exe" )
	{
		mv "$($env:LOCALAPPDATA)\Amazon\Kindle\application\renderer-test.exe" "$($env:LOCALAPPDATA)\Amazon\Kindle\application\renderer-test.deleted"
	}
}

LoadSettings
$deDrmPath = GetDeDrmPath
$ebookConvert = GetEbookConvert
EnsurePython
EnsureKindleApp



#Decrypt all downloaded kindle azw files, put them in storage
$target = NormalizePath "$PSScriptRoot\..\..\books\azw3"

$kindleloc = NormalizePath "$($Env:UserProfile)\Documents\My Kindle Content\"
push-location $kindleloc

ls -Directory | %{
	push-location $_.FullName
	$hasazw = ls "*.azw"
	if(($hasazw|measure).Count -eq 1)
	{
	
		$test = (Join-Path $target "$($hasazw[0].BaseName)_nodrm");
		$hasnodrm = (ls "$test.*" | measure).Count -ge 1
		if( !$hasnodrm )
		{
			python $dedrmpath "$($hasazw[0].FullName)"
			mv "$($hasazw[0].BaseName)_nodrm.*" $target
		}
	}
	pop-location
}

pop-location

write-host "converting to html"

$storage = NormalizePath "$PSScriptRoot\..\..\books\kindle_library"

$converted = @()

ls $target | %{
	$result = & "$PSScriptRoot\Convert-ToHtml.ps1" $_.FullName $storage $ebookconvert
	if($result)
	{
		$converted += $_.Fullname
	}
}

$library = NormalizePath "$PSScriptRoot\..\..\books\library"
$ebookslocation = NormalizePath "$PSScriptRoot\..\..\books\ebooks"
ls $ebookslocation -File | %{

	$result = & "$PSScriptRoot\Convert-ToHtml.ps1" $_.FullName $library $ebookconvert
	if($result)
	{
		$converted += $_.Fullname
	}
}
$converted | out-host
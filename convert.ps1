
param(
	[switch]$generateSettings,
	[switch]$fixKindleRender,
	[switch]$runTests
)

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

if($runTests)
{
	Describe "SettingsFile" {
		if( Test-Path $script:settingsFile )
		{
			mv $script:settingsFile "$($script:settingsFile).testbackup" -Force
		}
		It "is created if not exists" {
			LoadSettings
			$script:settings | should not be $null
			$script:settings.publishFolder | should not be $null
		}
		It "is not replaced if already exists" {
			$script:settings.sourceebooks = "aoeu"
			$script:settings | convertTo-Json | sc -Path $script:settingsFile
			$script:settings = $null
			LoadSettings
			$script:settings.sourceEbooks | should be "aoeu"
		}
		if( Test-Path "$($script:settingsFile).testbackup" )
		{
			mv "$($script:settingsFile).testbackup" $script:settingsFile -Force
		}
		else
		{
			rm $script:settingsFile
		}
		LoadSettings
	}
}

function GetSettingsPath
{
	param($key)
	
	$ExecutionContext.InvokeCommand.ExpandString($script:settings."$key") 
}

if($runTests)
{
	Describe "GetSettingsPath" {
		It "Expands string variables" {
			$oldvalue = $script.settings.sourceebooks
			$script:settings.sourceebooks = "`$PSScriptRoot"
			$path = GetSettingsPath "sourceEbooks"
			$path | should be "$PSScriptRoot"
			$script:settings.sourceebooks = $oldvalue
		}
	}
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

if($runTests)
{
	Describe "NormalizePath" {
		$tmpfolder = [System.IO.Path]::GetTempPath()+"test1234"
		if( Test-Path $tmpfolder )
		{
			rm $tmpfolder
		}
		It "creates folder if not exists" {
			NormalizePath $tmpfolder
			Test-Path $tmpfolder | should be $true
		}
		It "shortens paths" {
			$result = NormalizePath $tmpfolder+"\.."
			$result.Path | should be ([System.IO.Path]::GetTempPath().Trim("\"))
		}
		rm $tmpfolder
	}
}

function GetDeDrmPath
{
	if( !(test-path "$PSScriptRoot\DeDRM_tools-master" ))
	{
		[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
		if( !(Test-Path "$PSScriptRoot\master.zip") )
		{
			Invoke-WebRequest -Uri "https://github.com/apprenticeharper/DeDRM_tools/archive/master.zip" -OutFile "$PSScriptRoot\master.zip"
		}
		expand-archive "$PSScriptRoot\master.zip" -DestinationPath "$PSScriptRoot"
	}
	$dedrmpath = ls DeDRM_tools-master -Recurse -Filter "DeDRM_App.pyw" | select -first 1
	if( $dedrmpath -eq $null )
	{
		throw "dedrm cant be found"
	}
	return $dedrmpath
}

if($runTests)
{
	Describe "DeDrm" {
		It "is installed if not present" {
		#	rm -R -Force "$PSScriptRoot\DeDRM_tools-master" -ErrorAction SilentlyContinue
			$result = GetDeDrmPath
			$result | should not be $null
			Test-Path $result.FullName | should be $true
		}
	}
}

function EnsurePython
{
	if( (get-command python -ErrorAction SilentlyContinue) -eq $null )
	{
		throw "python cant be found, please make sure python2.7 is installed and available on the path"
	}
	return $true
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
	return $true
}

if($runTests)
{
	Describe "Installed Dependencies" {
		It "can find python" {
			EnsurePython | should be $true
		}
		It "can find calibre" {
			GetEbookConvert | should not be $null
		}
		It "can find kindle (not mandatory)" {
			EnsureKindleApp | should be $true
		}
	}
}

function FindFileIgnoreExt
{
	param($folder,$fileName)
	
	$testpath = (Join-Path $folder $filename)
	ls "$testpath.*"
}

function FileAlreadyImported
{
	param($drmFile)
	$target = NormalizePath (GetSettingsPath "decryptedStorage")
	$existing = FindFileIgnoreExt $target "$($drmFile.BaseName)*_nodrm"
	return $existing -ne $null
}

if($runTests)
{
	Describe "FileAleadyImported" {
		$tmpfolder = [System.IO.Path]::GetTempPath()+"test12345"
		if( Test-Path $tmpfolder )
		{
			rm -R -Force $tmpfolder
		}
		mkdir $tmpfolder
		$script:settings.decryptedStorage = Join-Path $tmpfolder "decrypted"
		mkdir $script:settings.decryptedStorage -ErrorAction SilentlyContinue
		It "can tell if file already imported" {
			sc -Value "." -Path (Join-path $script:settings.decryptedStorage "aoeu-othercrap_nodrm.txt")
			$test = new-object -TypeName System.IO.FileInfo -ArgumentList "aoeu.azw"
			FileAlreadyImported $test | should be $true
		}
		rm -R -Force $tmpfolder
	}
}

function DeDrmAndImport
{
	param($drmFile)
	if( FileAlreadyImported $drmFile )
	{
		return
	}
	EnsurePython
	$deDrmPath = GetDeDrmPath
	$target = NormalizePath (GetSettingsPath "decryptedStorage")
	python $deDrmPath.Fullname $drmFile.FullName
	$filter = Join-Path $drmFile.Directory "*_nodrm.*"
	mv $filter $target
}

function ImportKindleBooks
{
	$source = GetSettingsPath "sourceKindle"
	
	ls -path $source -filter "*.azw" -Recurse | %{
		DeDrmAndImport $_
	}
}

if( $runTests )
{
	Describe "ImportKindle" {
		$tmpfolder = [System.IO.Path]::GetTempPath()+"test12345"
		if( Test-Path $tmpfolder )
		{
			rm -R -Force $tmpfolder
		}
		mkdir $tmpfolder -ErrorAction SilentlyContinue
		$script:settings.decryptedStorage = Join-Path $tmpfolder "decrypted"
		mkdir $script:settings.decryptedStorage
		$script:settings.sourceKindle = Join-Path $tmpfolder "encrypted"
		mkdir $script:settings.sourceKindle
		ls "$PSScriptRoot\testbooks" | %{
			$targetfolder = Join-Path $script:settings.sourceKindle ($_.BaseName)
			mkdir $targetfolder
			cp $_.Fullname $targetFolder
		}
		
		It "converts books" {
			ImportKindleBooks
			$result = ls $script:settings.decryptedStorage
			$result.Length | should be 2
			$result[0].BaseName | should be "test-norender_nodrm"
		}
		
		rm -R -Force $tmpfolder
	}
}

function ToHtml
{
	param($from,$to)
	$fromfolder = NormalizePath (GetSettingsPath $from)
	$tofolder = NormalizePath (GetSettingsPath $to)
	$converted = @()
	ls $fromfolder -File | %{ 
		$result = & "$PSScriptRoot\Convert-ToHtml.ps1" $_.FullName $tofolder (GetEbookConvert)
		if($result)
		{
			$converted += $_.Fullname
		}
	}
	return $converted
}

if($runTests)
{
	return
}

if( $generateSettings )
{
	LoadSettings
	return
}
if( $fixKindleRender )
{
	EnsureKindleApp
	return
}

LoadSettings
if( !(Test-Path (GetSettingsPath "sourceKindle")) )
{
	Write-warning "Kindle storage folder not found, skipping decrypt"
}
else
{
	Write-Host "Decrypting kindle ebooks"
	ImportKindleBooks
}
write-host "converting to html"
ToHtml -from "decryptedStorage" -to "kindleLibrary"
ToHtml -from "sourceEbooks" -to "library"

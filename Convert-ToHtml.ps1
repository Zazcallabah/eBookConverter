# Input must be a decrypted file, calibre needs to be able to read it.

param($sourcefile,$targetfolder,$ebookconverterpath)
if($ebookconverterpath -eq $null)
{
	$eb=get-command ebook-convert -ErrorAction SilentlyContinue
	if($eb -eq $null)
	{
		throw "ebook-convert.exe not found"
	}
	$ebookconverterpath = $eb | select -ExpandProperty source
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Web
if((get-item $sourcefile ) -is [System.IO.DirectoryInfo])
{
	throw "Make sure $sourcefile is a file"
}
ls $sourcefile | %{
	$base = $_.BaseName
	Write-Host -nonewline "Looking for $base ... "
	if((ls -Path "$($targetfolder)\*\$base"|measure).Count -eq 0)
	{
		$source = $_.Fullname
		write-host "Found: $source"
		$tmpfolder = [system.io.path]::GetTempPath()
		$staging = $tmpfolder + [system.io.path]::GetRandomFileName() + ".htmlz"
$errorjson=""
		write-host "Converting to html"
		(get-host).UI.RawUI.ForegroundColor = "Gray"
		$errorfound = $false;
		& $ebookconverterpath $source $staging --insert-blank-line --embed-font-family "Lucida Sans Unicode" --insert-blank-line-size 2 --unsmarten-punctuation --minimum-line-height 140 --font-size-mapping "12,12,14,16,18,20,22,24" --filter-css "font-family,color,background-color,line-height" 2>&1 | %{
			$data = $_.ToString() -replace "[^ -~]",""
			if($_ -is [System.Management.Automation.ErrorRecord])
			{
				echo "$($source): $($_.Exception.Message)`n" >> errors.txt
				if($_.Exception.Message.Contains("DRMError") )
				{
					$errorfound = $true;
				}
			}
			return $data
		} | out-host

		(get-host).UI.RawUI.ForegroundColor = "White"
		if( $errorfound )
		{
			write-host -ForegroundColor Red "$base is encrypted, aborting"
			write-host "path: $source"
			return;
		}
		if( !(Test-Path $staging) )
		{
			write-error "conversion failed, zip not found"
			return
		}
		Write-host "Unzipping"
		mv $staging "$staging.zip"
		$tmpname = [system.io.path]::GetRandomFileName().Substring(0,8)
		[System.IO.Compression.ZipFile]::ExtractToDirectory("$staging.zip", $tmpfolder+$tmpname)
		$item = New-Item "$tmpfolder$tmpname\$base" -type file
		$r = [regex]"<title>([^<]*)</title>"
		$indexfilename = "$tmpfolder$tmpname\index.html"
		get-content "$PSScriptRoot\version.txt" >> $indexfilename
		$result = $r.Matches((gc $indexfilename)[0])
		$name = [System.Web.HttpUtility]::HtmlDecode($result.Groups[1].Value) -replace "[^ -~]","" -replace "/|<|\\|:|<|>|\||\*|""|\?",""

		Write-Host "adding custom style"
		$style = gc -Raw "$tmpfolder$tmpname\style.css" -encoding utf8
		$style += "a { color:#5998d6; }
p{ line-height:1.4em;}
body {
max-width:1000px;
margin:auto !important;
text-align:left !important;
color:#ddd;
background-color:#333;
font-family: 'Lucida Grande','Lucida Sans Unicode',Verdana,Helvetica,sans-serif
}"
		set-content -path "$tmpfolder$tmpname\style.css" -value $style -encoding utf8

		$index = 1
		while( Test-Path "$targetfolder\$name" )
		{
			write-host "$name already exists in $targetfolder"
			if( $index -eq 1 )
			{
				$name = $name + " Copy"
			}
			else
			{
				$name = $name + $index
			}
			$index++
		}

		write-host "Creating $name in $targetfolder" -Foregroundcolor Green
		mv "$tmpfolder\$tmpname" "$targetfolder\$name"
		return $true
	}
	else
	{
		write-host "already converted, skipping"
		return $false
	}
}
param($bookname,$target="archive")

$kindlelib = Resolve-Path "..\..\books\kindle_library"
$lib = Resolve-Path "..\..\books\library"
$result = @()
$result += ls "$kindlelib\$bookname*"
$result += ls "$lib\$bookname*"

$outfolder = "\\omicron\backup\books\"
if( Test-Path $outfolder )
{
	$result | ?{ !(Test-Path "$outfolder$target\$($_.Name)") } | %{
		Write-Host "Publishing $($_.Name) to $target"
		cp -Recurse -Force $_.FullName "$outfolder$target"
	}
}
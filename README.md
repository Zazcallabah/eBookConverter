# eBookConverter

Calibre is an ebook management and conversion tool. DeDrm is a ebook drm removal and decryption tool.

These scripts combine those tools with their dependencies to mass convert a downloaded kindle library to single page html documents.

## Features

The converted ebooks have the following features that normal ebooks dont:

* Continuous scroll. This is the reason these scripts exist. No ebook reader available has continuous scroll.
* Single-page html. Depending on the ebook, anchor tags will be placed for easier bookmarking.
* Paragraphs are separated by whitespace, not just marked by indentation.
* Typeface, line height, and font size similar to ao3. Unless the ebook specifies certain fonts.
* Page width constrained to a reasonable size.

## Instructions

* Install python2.7 and pycrypto, and possibly "pip install pylzma", make sure python.exe is available on the path
* Install calibre-portable into the calibre folder.
* run `convert.ps1 -generateSettings`, edit the resulting settings.json file to your liking
* run `convert.ps1`

### Linux

I haven't found a way to get the encrypted azw file on linux, only windows. However, if you have an azw you wish to decrypt, the following prerequisites must be completed:

* install python 2.7 and make sure `python` points to it
* install calibre: https://download.calibre-ebook.com/linux-installer.sh 
* download latest release of dedrm from apprentice harpers github
* `calibre-customize --add ./DeDRM_tools_6.6.3/Obok_calibre_plugin/obok_plugin.zip`
* `calibre-customize --add ./DeDRM_tools_6.6.3/DeDRM_calibre_plugin/DeDRM_plugin.zip` 
* `sudo apt install python-tk`
* `pip install pylzma`

then run `python ./DeDRM_tools_6.6.3/DeDRM_Windows_Application/DeDRM_App/DeDRM_lib/DeDRM_App.pyw <azw path>` to decrypt azw book

`Convert-ToHtml.ps1` should work as expected even on linux.

## settings.json

Values in the settings file will have variables expanded before being used. This means you can use $($Env:UserProfile) to refer
to the user folder, or any other environment variable you like. $PSScriptRoot refers to the folder relative to where the script is located.
"." and ".." can be used as normal to refer to locations relative to the current working directory - but this is not recommended unless
you always run the script from the same location.
Since the values are JSON encoded, backslashes need to be escaped.

The script uses the following properties

### sourceEbooks

> Example: `"$PSScriptRoot\storage\ebooks"`

If you have non-kindle ebooks you'd like to convert, place them in a folder and point this setting to that folder.

### library

> Example: `"$PSScriptRoot\output\ebooks"`

This is the location where the script dumps the finished converted html files. The script will also look in this location for files before it
converts an ebook, so no duplicates are generated.


### kindleLibrary

> Example: `"$PSScriptRoot\output\ebooks"`

If you want your converted kindle ebooks to be located somewhere else that your regular converted ebooks, change this setting.


### decryptedStorage

> Example: `"$PSScriptRoot\storage\decryptedkindle"`

This is the folder where decrypted kindle files are stored. They are not stored in the sourceKindle location, because that makes books show up twice in your kindle library.


### sourceKindle

> Example: `"$($Env:UserProfile)\\Documents\\My Kindle Content\\"`

This is the folder where the script will look for kindle ebooks. If you leave this to the default value, all you need to do is open 
the kindle app and download the ebooks. They should appear in the correct location.


### publishFolder

> Example: `"$PSScriptRoot\\published"`

Used by the movebook.ps1 script


## License

* The powershell scripts are written by me and licensed under the [MIT License](https://opensource.org/licenses/MIT).
* The test ebooks are in the public domain.

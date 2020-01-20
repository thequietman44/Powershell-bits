<#
.SYNOPSIS
    Copies source file(s) to destination folder on multiple remote PCs
.DESCRIPTION
    Copies source file(s) to destination folder on multiple remote PCs
.EXAMPLE
    PS C:\> Copy-ToMultipleComputers -source '.\Desktop\New Text Document.txt' -computers Server01,Server02,Server03 -destination "C$\Users\Administrator\Desktop\"
    Copies the "New Text Document.txt" file to the Admin Desktop on 3 servers
#>
function Copy-ToMultipleComputers {
    param (
        # Computer or list of computers to copy to
        [Parameter(Mandatory=$true)]
        $computers,

        # Source file or folder to copy to remote PC
        [Parameter(Mandatory=$true)]
        $source,

        # Destination folder on remote PC
        [Parameter(Mandatory=$true)]
        $destination,

        [switch]
        $Verify
    )

    foreach ($computer in $computers) {
        if ((Test-Path -Path \\$computer\$destination)) {
            $destFile = Copy-Item $source -Destination \\$computer\$destination -Recurse -passthru
            if ($verify){
                get-item $destFile
            }
        } else {
            "\\$computer\$destination is not reachable or does not exist"
        }
    }
}

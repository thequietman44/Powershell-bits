<#
.SYNOPSIS
    Parses a string containing First and Last name (and optionally a middle initial)
.DESCRIPTION
    Parses a string containing First and Last name (and optionally a middle initial)
    Outputs a PSCustomObject with 5 properties (FirstName, LastName, FirstInitial, MiddleInitial, LastInitial)
.EXAMPLE
    PS C:\> Get-FirstLastInitials "Smith, John E."
    Will return an object with the following properties:
        FirstName     : John
        LastName      : Smith
        FirstInitial  : J
        MiddleInitial : E
        LastInitial   : S
.EXAMPLE
    PS C:\> Get-FirstLastInitials "John Smith"
    Will return an object with the following properties:
        FirstName     : John
        LastName      : Smith
        FirstInitial  : J
        MiddleInitial :
        LastInitial   : S
.NOTES
    Parses data in the following formats:
        LastName, FirstName
        LastName, FirstName I.
        LastName, F. MiddleName
        LastName,FirstName
        LastName,FirstName I.
        FirstName LastName
        FirstName I. LastName
        F. MiddleName LastName

    Also trims leading and trailing whitespace from the input string
    and attempts to remove multiple spaces between names within the string
#>
function Get-FirstLastInitials {
    [CmdletBinding()]
    param (
        $name,

        [ValidateSet("UPPER","lower","Proper","Title")]
        [string]$case
    )

    # Remove leading/trailing whitespace from input string
    $name = $name.trim()

    if ($name -like "*,*"){ # name like "LastName, FirstName I." or "LastName, FirstName" or "LastName,FirstName"
        $firstName = (($name -split "\s*,\s*|\s")[1]) -replace "\.",""
        $lastName = (($name -split "\s*,\s*")[0])
        $middleName = (($name -split ",\s*|\s+")[-1]) -replace "\.",""
    } else {
        if ((($name -split "\s+").Count -gt 2)){ # name like "FirstName I. Lastname"
            $firstName = (($name -split "\s+")[0]) -replace "\.",""
            $lastName = (($name -split "\s+")[2])
            $middleName = (($name -split "\s+")[1]) -replace "\.",""
        } else { # name like "FirstName LastName"
            $firstName = (($name -split "\s+")[0]) -replace "\.",""
            $lastName = (($name -split "\s+")[1])
            $middleName = (($name -split "\s+")[2])
        }
    }
    # Make sure initial isn't null
    if (!($middleName)){
        $middleName = ""
    }

    # Normalize first/last name letter case
    if (($case -eq "Proper") -or ($case -eq "Title")){
        $firstName = ((Get-Culture).TextInfo).ToTitleCase($firstName.ToLower())
        $lastName = ((Get-Culture).TextInfo).ToTitleCase($lastName.ToLower())
        $middleName = ((Get-Culture).TextInfo).ToTitleCase($middleName.ToLower())
    } elseif ($case -eq "lower") {
        $firstName = $firstName.ToLower()
        $lastName = $lastName.ToLower()
        $middleName = $middleName.ToLower()
    } elseif ($case -eq "UPPER") {
        $firstName =$firstName.ToUpper()
        $lastName = $lastName.ToUpper()
        $middleName = $middleName.ToUpper()
    }
    # Make sure initials are capitalized
    $firstInitial = "$($firstName[0])".ToUpper()
    $middleInitial = "$($middleName[0])".ToLower()
    $lastInitial = "$($lastName[0])".ToUpper()

    # Create the output object
    $user = [PSCustomObject]@{
        firstName = $firstName
        middleName = $middleName
        lastName = $lastName
        firstInitial = $firstInitial
        middleInitial = $middleInitial
        lastInitial = $lastInitial
    }

    Write-Output $user

}

<#
.SYNOPSIS
    Using First and Last Name (and initials), attempts to match with a user in AD.
.DESCRIPTION
    Using First and Last Name (and initials), attempts to match with a user in AD.
    Exact matches (First and Last name) will be tried first, if no results are found
    Last name and first initial will be tried, followed by first name and last initial.

    Which level of matching was successful will be added as a property of the output object
    along with a count of matching results. Exact and last name matches with 1 result are
    high probability matches. First name matches and matches with more than 1 result should be
    reviewed manually to verify the correct user.

    This function can receive pipeline input from the Get-FirstLastInitials function,
    or the "Name" string can be piped directly and the function will attempt to parse it
    using the Get-FirstLastInitials function.

.EXAMPLE
    PS C:\> Get-FirstLastInitials "Smith, John E" | Get-ADMatchingUsers
    Returns a list of all users matching the provided name string
.EXAMPLE
    PS C:\> Get-ADMatchingUsers "Smith, John E"
    Returns a list of all users matching the provided name string. See sample output below:

        SamAccountName : john.smith
        GivenName      : John
        Initials       :
        Surname        : Smith
        Description    : Developer
        Mail           : john.smith@example.com
        MatchLevel     : Exact
        MatchCount     : 2

        SamAccountName : john.smith2
        GivenName      : John
        Initials       :
        Surname        : Smith
        Description    : Finance
        Mail           : john.smith2@example.com
        MatchLevel     : Exact
        MatchCount     : 2

.NOTES
    This function outputs a PSCustomObject (TypeName: System.Management.Automation.PSCustomObject),
    not an ADUser object (TypeName: Microsoft.ActiveDirectory.Management.ADUser).
    This means you will need to do a Get-ADUser on the SamAccountName property
    to get additional details or return the actual ADUser object.

    PS C:\> Get-AddsMatchingUsers "Smith, John E" | %{ Get-ADUser $_.samaccountname }
#>
function Get-AddsMatchingUsers {
    [CmdletBinding(DefaultParameterSetName='Name')]
    param (
        [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='FirstLastInitials')]
        [string]
        $firstName,

        [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='FirstLastInitials')]
        [string]
        $lastName,

        [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='FirstLastInitials')]
        [string]
        $firstInitial,

        [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='FirstLastInitials')]
        [string]
        $middleInitial,

        [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='FirstLastInitials')]
        [string]
        $lastInitial,

        # Can optionally accept a "Name" string as input and attempt to determine first/last initials 
        [Parameter(Mandatory=$false,Position=0,ValueFromPipelineByPropertyName,ParameterSetName='Name')]
        [string]
        $Name,

        # Return only matches of this type
        [Parameter(Mandatory=$false)]
        [string[]]
        [ValidateSet('Exact','LastName','FirstName','All')]
        $matchLevel
    )
    
    # Function to output a single user object
    function singleUserOutput {
        param (
            $match,
            $matchLevel
        )
        $userProperties = [ordered]@{
            SamAccountName = $match.SamAccountName
            GivenName = $match.GivenName
            Initials = $match.Initials
            Surname = $match.Surname
            Description = $match.Description
            Mail = $match.mail
            MatchLevel = $matchLevel
            MatchCount = $match.samaccountname.Count
        }
        $user = New-Object psobject -Property $userProperties
        return $user
    }

    # Function to output multiple user objects
    function multiUserOutput {
        param (
            [array]$matches,
            [string]$matchLevel
        )
        
        $matches | ForEach-Object {
            $userProperties = [ordered]@{
                SamAccountName = $_.SamAccountName
                GivenName = $_.GivenName
                Initials = $_.Initials
                Surname = $_.Surname
                Description = $_.Description
                Mail = $_.mail
                MatchLevel = $matchLevel
                MatchCount = $matches.samaccountname.Count
            }
        $userMulti = New-Object psobject -Property $userProperties
        $user += $userMulti
        }
        return $user
    }

    # If a Nmae string was supplied, parse it using the Get-AddsFirstLastInitials function
    if ($Name){
        $parsedName = Get-AddsFirstLastInitials $Name
        
        $firstName = $parsedName.FirstName
        $lastName = $parsedName.LastName
        $firstInitial = $parsedName.firstInitial
        $middleInitial = $parsedName.middleInitial
        $lastInitial = $parsedName.lastInitial
    }

    # Initialize global variable
    $user = @()

    # Try to get an exact match by first and last name
    $exactMatch = Get-ADUser -f { (surname -like $lastName) -and (givenname -like $firstName) } -Properties mail,description,initials

    if ($exactMatch.samaccountname.Count -eq 1){
        #"Exact Match"
        singleUserOutput -match $exactMatch -matchLevel "Exact"
    } elseif ($exactMatch.samaccountname.Count -eq 0){
        # Try to get a single exact match on last name and first initial
        #"No Exact Match"
        $firstInitialPattern = $firstInitial + "*"
        $lastMatch = Get-ADUser -f { (surname -like $lastName) -and (givenname -like $firstInitialPattern) } -Properties mail,description,initials
        if ($lastMatch.samaccountname.Count -eq 1){
            #"Last Match"
            singleUserOutput -match $lastMatch -matchLevel "LastName"
        } elseif ($lastMatch.samaccountname.Count -eq 0) {
            # Try to get a single exact match on last initial and first name
            #"No Last Match"
            $lastInitialPattern = $lastInitial + "*"
            $firstMatch = Get-ADUser -f { (surname -like $lastInitialPattern) -and (givenname -like $firstName) } -Properties mail,description,initials
            if ($firstMatch.samaccountname.Count -eq 1) {
                #"First Match"
                singleUserOutput -match $firstMatch -matchLevel "FirstName"
            } elseif ($firstMatch.samaccountname.Count -eq 0) {
                # Could not find user
                write-verbose "No match found for $firstName $lastName"
            } elseif ($firstMatch.samaccountname.Count -gt 1) {
                # Multiple possible matches
                write-verbose "Multiple FirstName matches for $firstName $lastName"
                multiUserOutput -matches $firstMatch -matchLevel "FirstName"
            }
        } elseif ($lastMatch.samaccountname.Count -gt 1) {
            # Multiple possible matches
            write-verbose "Multiple LastName matches for $firstName $lastName"
            multiUserOutput -matches $lastMatch -matchLevel "LastName"
        }
    } elseif ($exactMatch.samaccountname.Count -gt 1) {
        # Multiple possible matches
        write-verbose "Multiple Exact matches for $firstName $lastName"
        multiUserOutput -matches $exactMatch -matchLevel "Exact"
    } else {
        write-verbose "Wut?"
    }


    # Only output users with the specified match level
    if (($matchLevel) -and ($user.MatchLevel -eq $matchLevel)){
        Write-Output $user
    } elseif ($null -eq $matchLevel) {
        Write-Output $user
    }
    
}

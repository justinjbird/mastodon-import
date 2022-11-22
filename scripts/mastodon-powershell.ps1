$script:checked = $hashtagusers = $script:links = @()
$PSDefaultParameterValues["*:IncludeExpansions"] = $true
$PSDefaultParameterValues["*:ErrorAction"] = "SilentlyContinue"

function Find-Links ($users) {
    Write-Output "Starting with $($users.Count) users"
    $users = $users | Where-Object Protected -eq $false | Sort-Object -Unique
    $users = $users | Where-Object UserName -notin $script:checked
    if ((Test-Path -Path ./data/matches.csv)) {
        $csv = @((Import-Csv -Path ./data/matches.csv))
    } else {
        $csv = @()
    }
    
    $users = $users | Where-Object UserName -notin $csv.TwitterUserName
    Write-Output "Now processing $($users.Count) users"

    foreach ($user in $users) {
        $script:checked += $user.UserName
        $results = $user | Find-TwitterMastodonLinks -Verbose | Sort-Object -Unique
        foreach ($result in $results) {
            $script:export = $true
            Write-Output "Found $($result.MastodonAccountAddress)"
            $csv += $result
        }
    }
    if ($script:export) {
        Write-Output "Exporting to csv"
        $csv | Export-Csv -Path ./data/matches.csv
    }
}

# from a list that steph locke created
$stephlocke = Get-TwitterListMember -Id 1491474973998915587
Find-Links $stephlocke

# from the redgate 100
$redgate100 = Get-TwitterListMember -Id 1569973251161616385
Find-Links $redgate100

# from the sqlfamily hashtag
$search = @{
    SearchString      = "sqlfamily"
    NoPagination      = $true
    IncludeExpansions = $false
}

$authors = (Search-Tweet @search).AuthorId | Sort-Object -Unique

foreach ($author in $authors) {
    $params = @{
        ExpansionType = 'User'
        Endpoint      = "https://api.twitter.com/2/users/$author"
    }
    $hashtagusers += Invoke-TwitterRequest -RequestParameters $params
}

Find-Links $hashtagusers

# pass itself
$passuser = Get-TwitterUser -User PASSDataSummit -IncludeExpansions:$false
Find-Links $passuser

# pass followers
$passfollowers = Get-TwitterFollowers -Id $passuser.Id
Find-Links $passfollowers


# pass following
$passfriends = Get-TwitterFriends -Id $passuser.Id
Find-Links $passfriends
 
if ((Test-Path -Path ./data/matches.csv) -and $script:export) {
    if ((Test-Path -Path ./data/sql_accounts.csv)) {
        Remove-Item ./data/sql_accounts.csv
    }

    Import-Csv -Path ./data/matches.csv | Sort-Object MastodonAccountAddress |
        Select-Object @{
            Label      = "Account address"
            Expression = { $PSItem.MastodonAccountAddress }
        },
        @{
            Label      = "Show boosts"
            Expression = { "true" }
        } | Export-Csv -Path ./sql_accounts.csv
}
<#
.Synopsis
   Configure BGinfo based on OU

.DESCRIPTION
   When running the script it check´s where the server is located in the AD and extract the path to configure BGinfo for the right environment

.EXAMPLE
   Set-BGInfo.ps1
   Basic run

.EXAMPLE
   Set-BGInfo.ps1 -FirstRun
   First run of the script on the server to verify that EventSource in Application Log exist and to add path to Registry Run. The script will then run
   on every logon to the server.
   
   If you move the BGInfo-folder you need to run "firstrun" again.

.EXAMPLE
   Set-BGInfo.ps1 -Reset
   Removes registry run value if the BGInfo are not to be used or folder is deleted.

.NOTES
   Filename: Set-BGInfo.ps1
   Author: Christian Damberg
   Website: https://www.damberg.org
   Email: christian@damberg.org
   Modified date: 2022-04-04
   Version 1.0 - First release
    
   For the script to work you need to have configured BGinfo for your environment.
   Downloadlink and instructions for BGInfo https://docs.microsoft.com/en-us/sysinternals/downloads/bginfo
      
   Before even running the script you need to set some variables in the script.
   - Domainname
   - Name on OUs where your servers are located. In this script i have Production, Acceptance, Test and Tier.
   - Name on Source in Application-log. In this script i have BGinfo.
   - Name of Configfiles for BGInfo
   
#>
    #------------------------------------------------#
    # Parameters

    Param(
    [Parameter(Mandatory=$false)]
    [Switch]$Firstrun,
    [Parameter(Mandatory=$false)]
    [Switch]$Reset
    )
    #------------------------------------------------#
    # Functions in script

    function Test-EventLogSource {
        Param(
            [Parameter(Mandatory=$true)]
            [string] $SourceName
        )
           [System.Diagnostics.EventLog]::SourceExists($SourceName)
        }
    #------------------------------------------------#
    # Variables to the script

    [string]$DomainName = "corp.viamonstra.com"
    [String]$eventlogsource = 'BGinfo'
    [string]$registrypath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
    
    #------------------------------------------------#
    # Firstrun check 
      
    if($Firstrun -eq $true)
    {
        # Eventlogsource
        if((Test-EventLogSource $eventlogsource) -eq $true)
            { 
                write-host "Evebtlogsource $eventlogsource exist" -ForegroundColor green
            }
        else 
            {
                Write-Host "Creating new source in applicationlog called BGInfo" -ForegroundColor green
                New-Eventlog -LogName application -Source BGInfo
            }

        # Registry run check for BGinfo run
        $RegistryRunVaule = Get-ItemProperty -Path $registrypath -Name BGinfo -ErrorAction SilentlyContinue 

        if ($RegistryRunVaule -eq $null)
            {
                write-host "RegistryRun missing value, adding it to Registry" -ForegroundColor Green
                New-ItemProperty -Path $registrypath -Name BGInfo -PropertyType string -Value "powershell.exe -executionpolicy unrestricted -file $PSScriptRoot\Set-BGinfo.ps1" 
            }
        else
            {
                Write-host "Registry for run exist" -ForegroundColor green
            }

    }

    if($reset -eq $true)

    {
        Remove-ItemProperty -Path $registrypath -Name BGINFO -ErrorAction SilentlyContinue
        write-host 'Settings in Registry deleted' -ForegroundColor Red
        exit
    }

    #------------------------------------------------#
    # query to verify OU-path

    $strName = $env:COMPUTERNAME
    $strNamesearch = "$($strName)$"
    $strFilter = "(&(objectCategory=Computer)(samAccountName=$strNamesearch))"
    
    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $objSearcher.Filter = $strFilter
    
    $objPath = $objSearcher.FindOne()
    $objDetails = $objPath.GetDirectoryEntry()
    $objDetails.RefreshCache("canonicalName")
    
    $OUPath =  ($objDetails.canonicalname -replace "/$($strName)") -replace "$domainname/"

    
    #------------------------------------------------#    
    # Compare OU-path with variable and run BGInfo 

    # Check XML after which configfile to use
    
    [XML]$xmlfile = Get-Content .\BGinfo.xml

    foreach ($item in $xmlfile.bginfo.setup.name)
        {
        
            if($OUPath -like "*$item*")
            {
                write-host "$item exist in $OUPath" -ForegroundColor Green
                $ExtractedValue = $item
            }
           }
        
        $data = $xmlfile.BGInfo.Setup | Where-Object {$_.name -contains $ExtractedValue}

    # configfile to use
    $bginfoconfig = $data.config 

    # Construct executecommand
    $bgInfoExecutePath = "$PSScriptRoot\Bginfo64.exe /i$PSScriptRoot\$bgInfoConfig /timer:0 /nolicprompt"
    
    # Run BGinfo with BGinfo config
    Invoke-Expression $bgInfoExecutePath
    Write-EventLog -LogName Application -Source BGinfo -EntryType Information -Message "BGinfo configured for $ExtractedValue at logon by $env:username" -EventId 0

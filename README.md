# Set-BGInfo
<b>Installi-nstructions</b><br>
1. Create your BGinfo-config-files
2. Download BGInfo64.exe from Sysinternals https://docs.microsoft.com/en-us/sysinternals/downloads/bginfo
3. Edit BGinfo.xml with the names on your OU:s and what Config each should have
4. Save all files in the same folder
5. Run Set-BGinfo.ps1 -Firstrun

<B>What is this...</b><br>
This script will run on each logon to the server. 

When the script are running it gets the computername och checks against AD where it is located. Then it compares with
BGinfo.xml and get the right config for BGInfo.

In my exemple I have four different OU, Production, Acceptance, Test and Tier.

<B>Way of deployment</b><br>
The script by default is created to be use manually by copying it to the server but it you want to deploy it by using
MEMCM you need to add two things in your deploymentscript more then copying the files to the server.

For the logging i use the eventlog "Application" and added a new source. 
- (New-Eventlog -LogName application -Source BGInfo)

To get BGInfo to run on each logon you need to add a row to registry run.
- (New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name BGInfo -PropertyType string -Value "powershell.exe -executionpolicy unrestricted -file $PSScriptRoot\Set-BGinfo.ps1" )

Or...add to run the script from the final location with the switch -Firstrun

<b>Config</b><br>
I use a XML-file to store info about config and OU-name.

<B>Requirements</B><br>
- At least Powershell 5
- Your OU-structure for servers need to have different OU:s for different Environments (Production, Acceptance, Test and Tier)
- You need to create your BGInfo-config for each Environment before you deploy the script.

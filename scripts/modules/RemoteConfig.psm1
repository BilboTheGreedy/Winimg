function Copy-CloudbaseConf {
#find cloudbase-init.conf on secondary drive 
Get-PSDrive -PSProvider FileSystem| %{if (test-path ("{0}cloudbase-init.conf" -f $_.Root)) {$cbc= $_.root+"cloudbase-init.conf"}}
## Replace config files
$CloudbaseInitFolder = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf"
$configFile = "cloudbase-init.conf"
$configFileUnattend = "cloudbase-init-unattend.conf"
New-Item -Path $CloudbaseInitFolder -Name $configFile -Value (cat $cbc -raw) -Force -ItemType file -Confirm:$false | Out-Null
New-Item -Path $CloudbaseInitFolder -Name $configFileUnattend -Value (cat $cbc -raw) -Force -ItemType file -Confirm:$false | Out-Null
}

Function Download() {
    Param(
        [Parameter(Position=1,Mandatory=$True)]
        [string]$URL,

        [Parameter(Position=2,Mandatory=$True)]
        [string]$Outpath,

        [Parameter(Position=3,Mandatory=$False)]
        [string]$Proxyserver

    )

        if ($Proxyserver){
            try{
                Invoke-RestMethod -Method Get -Uri $Url -OutFile $Outpath -UseDefaultCredentials -Proxy $Proxyserver
             }
             catch{
                throw "Download failed with proxy $Proxyserver" 
             }
        }
        else {
            try{
                Invoke-RestMethod -Method Get -Uri $Url -ea stop -OutFile $Outpath
             }
             catch{
                throw "Download failed" 
             }
        } 
    
    
}


Function InstallMSI() {
    Param(
        [Parameter(Position=1,Mandatory=$True)]
        [string]$Path,

        [Parameter(Position=2,Mandatory=$True)]
        [string]$ArgumentList
    )
    $p = Start-Process -Wait `
    -PassThru `
    -Verb runas `
    -FilePath msiexec `
    -ArgumentList "$ArgumentList"
    if ($p.ExitCode -ne 0)
    {   
        throw "Installing $Path failed."
    }

}


Function Finalize() {
    $ErrorActionPreference = "SilentlyContinue"
    & "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\SetSetupComplete.cmd"
    Optimize-Volume -DriveLetter C -Defrag -ReTrim -SlabConsolidate -Verbose
    $reg_winlogon_path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $reg_winlogon_path -Name AutoAdminLogon -Value 0
    Remove-ItemProperty -Path $reg_winlogon_path -Name DefaultUserName -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $reg_winlogon_path -Name DefaultPassword -ErrorAction SilentlyContinue

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name SkipRearm -Value 0
    ##Clear recovery - this gets readded after sysprep
    Remove-Item -Path C:\Recovery -Force -Recurse -Confirm:$false
    ##Clear autounattend logs
    Remove-Item -Path C:\Windows\Panther -Force -Recurse -Confirm:$false
    ##Remove windows updates downloads
    Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false
    #Sysprep
    $ScriptBlock = {
        Unregister-ScheduledTask -TaskName "sysprep" -Confirm:$false
        Get-PSDrive -PSProvider FileSystem | % {
            if ((test-path ($_.root+"\unattend.xml")) -eq $true){
                    $ua=$_.root+"\unattend.xml"
                    C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:$ua 
                }
            }
    }
    $opt = New-ScheduledJobOption -RunElevated
    Register-ScheduledJob -ScriptBlock $ScriptBlock -Name "sysprep" -ScheduledJobOption $opt -RunNow
    Get-EventLog -LogName * | ForEach { Clear-EventLog $_.Log } 
}

Function Invoke-Finalize() {
    Param(
        [Parameter(Position=1,Mandatory=$True)]
        [string]$ComputerName,
        [Parameter(Position=2,Mandatory=$True)]
        [PSCredential]$Credential
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock ${Function:Finalize} 
}


Function Invoke-CloudbaseInit() {
    Param(
        [Parameter(Position=1,Mandatory=$True)]
        [string]$ComputerName,

        [Parameter(Position=2,Mandatory=$True)]
        [string]$URL,

        [Parameter(Position=3,Mandatory=$True)]
        [string]$Outpath,

        [Parameter(Position=4,Mandatory=$False)]
        [switch]$UseProxy,

        [Parameter(Position=5,Mandatory=$False)]
        [string]$Proxyserver,
        [Parameter(Position=6,Mandatory=$True)]
        [string]$ArgumentList,
        [Parameter(Position=7,Mandatory=$True)]
        [PSCredential]$Credential
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock ${Function:Download} -ArgumentList $URL,$Outpath,$Proxyserver
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock ${Function:InstallMSI} -ArgumentList $Outpath,$ArgumentList
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock ${Function:Copy-CloudbaseConf}
}


Export-ModuleMember -Function "Invoke-Finalize"
Export-ModuleMember -Function "Invoke-CloudbaseInit"
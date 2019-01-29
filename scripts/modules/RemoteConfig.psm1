function Copy-CloudbaseConf {
$config = @"
[DEFAULT]
username=Administrator
groups=Administrators
inject_user_password=false
config_drive_raw_hhd=true
config_drive_cdrom=true
config_drive_vfat=true
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
verbose=true
debug=true
logdir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
logfile=cloudbase-init-unattend.log
default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN
logging_serial_port_settings=
mtu_use_dhcp_config=true
ntp_use_dhcp_config=true
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
metadata_services=cloudbaseinit.metadata.services.configdrive.ConfigDriveService,cloudbaseinit.metadata.services.httpservice.HttpService,cloudbaseinit.metadata.services.ec2service.EC2Service,cloudbaseinit.metadata.services.maasservice.MaaSHttpService
plugins=cloudbaseinit.plugins.common.mtu.MTUPlugin,
        cloudbaseinit.plugins.windows.ntpclient.NTPClientPlugin,
        cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin,
        cloudbaseinit.plugins.windows.createuser.CreateUserPlugin,
        cloudbaseinit.plugins.common.networkconfig.NetworkConfigPlugin,
        cloudbaseinit.plugins.windows.licensing.WindowsLicensingPlugin,
        cloudbaseinit.plugins.common.sshpublickeys.SetUserSSHPublicKeysPlugin,
        cloudbaseinit.plugins.windows.extendvolumes.ExtendVolumesPlugin,
        cloudbaseinit.plugins.common.setuserpassword.SetUserPasswordPlugin,
        cloudbaseinit.plugins.common.userdata.UserDataPlugin,
        cloudbaseinit.plugins.windows.winrmlistener.ConfigWinRMListenerPlugin,
        cloudbaseinit.plugins.windows.winrmcertificateauth.ConfigWinRMCertificateAuthPlugin,
        cloudbaseinit.plugins.common.localscripts.LocalScriptsPlugin
allow_reboot=false
stop_service_on_exit=false
check_latest_version=false
"@

## Replace config files
$CloudbaseInitFolder = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf"
$configFile = "cloudbase-init.conf"
$configFileUnattend = "cloudbase-init-unattend.conf"
New-Item -Path $CloudbaseInitFolder -Name $configFile -Value $config -Force -ItemType file -Debug -Confirm:$false | Out-Null
New-Item -Path $CloudbaseInitFolder -Name $configFileUnattend -Value $config -Force -ItemType file -Debug -Confirm:$false | Out-Null
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
    Get-EventLog -LogName * | ForEach { Clear-EventLog $_.Log } 
    $ScriptBlock = '
    Unregister-ScheduledTask -TaskName "sysprep" -Confirm
    $false;C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:"C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml"
    '
    $opt = New-ScheduledJobOption -RunElevated
    Register-ScheduledJob -ScriptBlock $ScriptBlock -Name "sysprep" -ScheduledJobOption $opt -RunNow | Out-Null
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
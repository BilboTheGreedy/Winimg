param
(
    [string]$CloudbaseInitMsiUrl = 'https://www.cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi'
)

$ErrorActionPreference = "Stop"


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
Write-Host "Replace cloudbase-init confg files... "
New-Item -Path $CloudbaseInitFolder -Name $configFile -Value $config -Force -ItemType file -Debug -Confirm:$false
New-Item -Path $CloudbaseInitFolder -Name $configFileUnattend -Value $config -Force -ItemType file -Debug -Confirm:$false
    
}




try {

    $Host.UI.RawUI.WindowTitle = "Downloading Cloudbase-Init..."
    Write-Host "Downloading Cloudbase-Init..."
    $CloudbaseInitMsiPath = "$ENV:Temp\CloudbaseInitSetup_Stable_x64.msi"
    $CloudbaseInitMsiLog = "C:\\installation.log"

    if ($ENV:UseProxy){
        try{
            Invoke-RestMethod -Method Get -Uri $CloudbaseInitMsiUrl -OutFile $CloudbaseInitMsiPath -UseDefaultCredentials -Proxy $ENV:Proxyserver
         }
         catch{
            Write-Host "Download failed with proxy $ENV:Proxyserver" 
         }
    }
    else {
        try{
            Invoke-RestMethod -Method Get -Uri $CloudbaseInitMsiUrl -ea stop -OutFile $CloudbaseInitMsiPath
         }
         catch{
            Write-Host "Download failed" 
         }
    }


    $Host.UI.RawUI.WindowTitle = "Installing Cloudbase-Init..."
    Write-Host "Installing Cloudbase-Init..."

    $p = Start-Process -Wait `
                       -PassThru `
                       -Verb runas `
                       -FilePath msiexec `
                       -ArgumentList "/i $CloudbaseInitMsiPath /qn /l*v $CloudbaseInitMsiLog"
    if ($p.ExitCode -ne 0)
    {   
        Write-Host "Installing $CloudbaseInitMsiPath failed. Log: $CloudbaseInitMsiLog"
        throw "Installing $CloudbaseInitMsiPath failed. Log: $CloudbaseInitMsiLog"
    }

    Copy-CloudbaseConf
} catch {
    $host.ui.WriteErrorLine($_.Exception.ToString())
    throw
}
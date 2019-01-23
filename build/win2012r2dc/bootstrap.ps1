winrm quickconfig -q

winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'

$networkListManager = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}"))
$connections = $networkListManager.GetNetworkConnections()

$connections | ForEach-Object {
    Write-Output $_.GetNetwork().GetName()"category was previously set to"$_.GetNetwork().GetCategory()
    $_.GetNetwork().SetCategory(1)
    Write-Output $_.GetNetwork().GetName()"changed to category"$_.GetNetwork().GetCategory()
}

Restart-Service -Name WinRM

Write-Log -message "enabling RDP"
$rdp_wmi = Get-CimInstance -ClassName Win32_TerminalServiceSetting -Namespace root\CIMV2\TerminalServices
$rdp_enable = $rdp_wmi | Invoke-CimMethod -MethodName SetAllowTSConnections -Arguments @{ AllowTSConnections = 1; ModifyFirewallException = 1 }
if ($rdp_enable.ReturnValue -ne 0) {
    $error_message = "failed to change RDP connection settings, error code: $($rdp_enable.ReturnValue)"
    Write-Log -message $error_message -level "ERROR"
    throw $error_message
}

Write-Log -message "enabling NLA authentication for RDP"
$nla_wmi = Get-CimInstance -ClassName Win32_TSGeneralSetting -Namespace root\CIMV2\TerminalServices
$nla_wmi | Invoke-CimMethod -MethodName SetUserAuthenticationRequired -Arguments @{ UserAuthenticationRequired = 1 } | Out-Null
$nla_wmi = Get-CimInstance -ClassName Win32_TSGeneralSetting -Namespace root\CIMV2\TerminalServices
if ($nla_wmi.UserAuthenticationRequired -ne 1) {
    $error_message = "failed to enable NLA"
    Write-Log -message $error_message -level "ERROR"
    throw $error_message
}


$Command = @'
Unregister-ScheduledTask -TaskName "packer-shutdown" -Confirm:$false
C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:"C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml"
'@
$Path = "C:\windows\temp\shutdown.ps1"
Write-Output "Register Shutdown command..."
Set-Content -Value $Command -Path $Path
schtasks /create /RU "NT AUTHORITY\SYSTEM" /tn "packer-shutdown" /tr "Powershell.exe -file $Path" /sc onevent /ec system /mo *[system/eventid=9999]

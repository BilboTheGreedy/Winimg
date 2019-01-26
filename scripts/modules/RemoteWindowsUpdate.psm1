
# Import-Module -Verbose -Force RemoteWindowsUpdate.psm1
# Invoke-WindowsUpdate -AsJob -AutoReboot -ComputerName -Cred PSCredential

$InitScript = {
    # Windows Update(Microsoft Update)
    Function Install-WindowsUpdate {
        Param(
            [Parameter(Position=1,Mandatory=$False)]
            [switch]$ListOnly
        )
        $ErrorActionPreference = "Stop"

        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $searcher = $updateSession.CreateUpdateSearcher()

        $searcher.ServerSelection = 0

        $searchResult = $searcher.search("IsInstalled=0")

        if ($ListOnly) {
            return $searchResult.Updates
        }
    
        if ($searchResult.Updates.Count -eq 0) {
            return
        }

        $updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
        $searchResult.Updates | ForEach-Object {
            $update = $_
            if ($update.InstallationBehavior.CanRequestUserInput) {
                return
            }
            if (-not $_.EulaAccepted) {
                $_.AcceptEula()
            }
            $updatesToDownload.add($update) | Out-Null
        }

        if ($updatesToDownload.Count -eq 0) {
            throw "Could not accept the EULA"
        }

        $downloader = $updateSession.CreateUpdateDownloader()
        $downloader.Updates = $updatesToDownload
        $downloader.Download() | Out-Null


        $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        $searchResult.Updates | Where-Object {
            $_.IsDownloaded
        } | ForEach-Object {
            $updatesToInstall.add($_) | Out-Null
        }

        if ($updatesToInstall.Count -eq 0) {
            throw "Update Download Faild"
        }

        $installer = $updateSession.CreateUpdateInstaller()
        $installer.Updates = $updatesToInstall
        $installationResult = $installer.Install()

        if ($installationResult.ResultCode -ne 2) {
            throw "Update Install Faild"
        }
    }
    Function Install-RemoteWindowsUpdate {
        Param(
            [Parameter(Position=1,Mandatory=$True)]
            [string]$Script
        )
        $ErrorActionPreference = "Stop"

        $ScriptBlock = Invoke-Expression $Script

        $TaskPath = "\Microsoft\Windows\PowerShell\ScheduledJobs\"
        $DefinitionName = "RemoteWindowsUpdate"

        $Job = Get-ScheduledJob -Name $DefinitionName -ErrorAction "SilentlyContinue"
        if ($Job) {
            $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $DefinitionName
            if ($task.state -eq "Running") {
                "Windows Updating..."
            }
            Unregister-ScheduledJob -Name $DefinitionName
        }

        $opt = New-ScheduledJobOption -RunElevated
        
  
        Register-ScheduledJob -ScriptBlock $ScriptBlock -Name $DefinitionName -ScheduledJobOption $opt -RunNow | Out-Null

        $Task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $DefinitionName
        while ($Task.State -eq "Running") {
            Start-Sleep -Seconds 5
            $Task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $DefinitionName
        }

        Unregister-ScheduledJob -Name $DefinitionName

        Test-Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    }
}

$RemoteWindowsUpdate = {
    Param(
        [Parameter(Position=1,Mandatory=$True)]
        [string]$ComputerName,

        [Parameter(Position=2,Mandatory=$False)]
        [switch]$AutoReboot,

        [Parameter(Position=3,Mandatory=$False)]
        [switch]$ListOnly,
        [Parameter(Position=4,Mandatory=$True)]
        [string]$LogPath,
        [Parameter(Position=5,Mandatory=$True)]
        [PSCredential]$Cred
    )

    $ErrorActionPreference = "Stop"
    
    Set-Location $using:pwd

    $RebootRequired = Invoke-Command -ComputerName $ComputerName -ScriptBlock ${Function:Install-RemoteWindowsUpdate} -ArgumentList ("{" + ${Function:Install-WindowsUpdate}.ToString() + "}") -Credential $Cred

    if ($RebootRequired -and $AutoReboot) {
        Restart-Computer $ComputerName -Wait -Force -Credential $Cred -Protocol WSMan
    }

    $AvailableUpdates = Invoke-Command -ComputerName $ComputerName -ScriptBlock ${Function:Install-WindowsUpdate} -ArgumentList $True  -Credential $Cred

    $FilePath = "{0}_{1}_{2}.txt" -f $LogPath,$ComputerName,(Get-Date -f "yyyyMMdd")
    if ($AvailableUpdates) {
        $updates = $AvailableUpdates | Select-Object @{L="KB";E={$_.KBArticleIds -join ","}},Title,LastDeploymentChangeTime
        $updates | ConvertTo-Csv -NTI | Out-File -Encoding Default -FilePath $FilePath -Force -Append
        return $False
    } else {
        $hotfix = invoke-command -ScriptBlock{ gwmi Win32_QuickFixEngineering} -ComputerName $ComputerName -Credential $Cred | Sort-Object InstalledOn
        $hotfix | Select-Object Description, HotFixID, InstalledOn | ConvertTo-Csv -NTI | Out-File -Encoding Default -FilePath $FilePath -Force -Append
        return $true
    }
}

Function Invoke-WindowsUpdate {
    Param(
        [Parameter(Position=1,Mandatory=$True)]
        [string]$ComputerName,

        [Parameter(Position=2,Mandatory=$False)]
        [switch]$AutoReboot,

        [Parameter(Position=3,Mandatory=$False)]
        [string]$LogPath,

        [Parameter(Position=4,Mandatory=$False)]
        [switch]$ListOnly,
        [Parameter(Position=5,Mandatory=$True)]
        [PSCredential]$Cred
    )

        Start-Job -Name $ComputerName -InitializationScript $InitScript -ScriptBlock $RemoteWindowsUpdate -ArgumentList $ComputerName,$AutoReboot,$ListOnly,$LogPath,$Cred  | Wait-Job | Receive-Job -AutoRemoveJob -Wait
    
}

Export-ModuleMember -Function "Invoke-WindowsUpdate"


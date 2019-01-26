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

Function Optimize() {
    $ErrorActionPreference = "SilentlyContinue" 
    ##
    Optimize-Volume -DriveLetter C -Defrag -ReTrim -SlabConsolidate -Verbose
    ##Clear recovery - this gets readded after sysprep
    Remove-Item -Path C:\Recovery -Force -Recurse -Confirm:$false
    ##Clear autounattend logs
    Remove-Item -Path C:\Windows\Panther -Force -Recurse -Confirm:$false
    ##Remove windows updates downloads
    Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false

    ##Zero out disk to be able to shrink it even more.
    $path = "C:\zero"
    $volume = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $block_size = 32mb
    $leftover_size = $volume.Size * 0.05
    $file_size = $volume.FreeSpace - $leftover_size
    $data_array = New-Object -TypeName byte[]($block_size)
    $stream = [System.IO.File]::OpenWrite($path)
    try {
        $current_file_size = 0
        while ($current_file_size -lt $file_size) {
            $stream.Write($data_array, 0, $data_array.Length)
            $current_file_size += $data_array.Length
        }
    } finally {
        if ($stream) {
            $stream.Close()
        }
    }
    Remove-Item -Path $path -Force | Out-Null
    
    ##Shrink partition as much as possible.
    $partitionInfo = Get-Partition -DriveLetter C
    $MinSize = (Get-PartitionSupportedSize -DriveLetter C).SizeMin
    $CurrSize = $partitionInfo.Size/1GB
    Write-Output "Current partition size: $CurrSize GB"
    # Leave free space for making sure Sysprep finishes successfuly
    $newSizeGB = [int](($MinSize + $FreeSpace)/1GB) + 1
    $NewSize = $newSizeGB*1GB
    Write-Output "New partition size: $newSizeGB GB"
}


Function Invoke-DownloadAndInstall() {
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
}

Function Invoke-Optimize() {
    Param(
        [Parameter(Position=1,Mandatory=$True)]
        [string]$ComputerName,
        [Parameter(Position=2,Mandatory=$True)]
        [PSCredential]$Credential
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock ${Function:Optimize} 
   
}
Export-ModuleMember -Function "Invoke-Optimize"
Export-ModuleMember -Function "Invoke-DownloadAndInstall"
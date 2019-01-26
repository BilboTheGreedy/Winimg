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
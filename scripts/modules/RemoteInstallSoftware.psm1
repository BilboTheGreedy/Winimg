Function Download() {
    Param(
        [Parameter(Position=1,Mandatory=$True)]
        [string]$ComputerName,

        [Parameter(Position=2,Mandatory=$True)]
        [string]$URL,

        [Parameter(Position=3,Mandatory=$True)]
        [string]$Outpath,

        [Parameter(Position=5,Mandatory=$False)]
        [string]$Proxyserver,

        [Parameter(Position=6,Mandatory=$True)]
        [PSCredential]$Credential
    )
    Invoke-Command -ComputerName $ComputerName -Credential $Cred -ScriptBlock {
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
    
}


Function InstallMSI() {
    Param(
        [Parameter(Position=1,Mandatory=$True)]
        [string]$ComputerName,

        [Parameter(Position=2,Mandatory=$True)]
        [string]$Path,

        [Parameter(Position=3,Mandatory=$True)]
        [string]$ArgumentList,

        [Parameter(Position=4,Mandatory=$True)]
        [PSCredential]$Credential
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
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock ${Function:Download} -ArgumentList $ComputerName,$URL,$Outpath,$Proxyserver,$Cred
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock ${Function:InstallMSI} -ArgumentList $ComputerName,$Outpath,$ArgumentList,$Cred
}

Export-ModuleMember -Function "Invoke-DownloadAndInstall"
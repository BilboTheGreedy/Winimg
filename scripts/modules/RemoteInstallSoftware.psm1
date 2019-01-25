Function Download() {
    Param(
        [Parameter(Position=1,Mandatory=$True)]
        [string]$ComputerName,

        [Parameter(Position=2,Mandatory=$True)]
        [string]$URL,

        [Parameter(Position=3,Mandatory=$True)]
        [string]$Outpath,

        [Parameter(Position=4,Mandatory=$False)]
        [switch]$UseProxy,

        [Parameter(Position=5,Mandatory=$True)]
        [string]$Proxyserver,

        [Parameter(Position=6,Mandatory=$True)]
        [PSCredential]$Cred
    )

    if ($UseProxy){
        try{
            Invoke-RestMethod -Method Get -Uri $Url -OutFile $Outpath -UseDefaultCredentials -Proxy $ENV:Proxyserver
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
        [string]$ComputerName,

        [Parameter(Position=2,Mandatory=$True)]
        [string]$URL,

        [Parameter(Position=3,Mandatory=$True)]
        [string]$Path,

        [Parameter(Position=4,Mandatory=$False)]
        [string]$ArgumentList,

        [Parameter(Position=5,Mandatory=$True)]
        [string]$Proxyserver,

        [Parameter(Position=6,Mandatory=$True)]
        [PSCredential]$Cred
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
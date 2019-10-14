Function Set-NetCfg {
    Param(
        [Parameter(Position=1,Mandatory=$False)]
        [int]$Index
    )
    #IP
    #MASK
    #GW
    #DNS
    #Routes?
    #Proxy?
    Get-NetAdapter -InterfaceIndex $Index

}
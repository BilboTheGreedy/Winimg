$ErrorActionPreference = "SilentlyContinue" 
##
Optimize-Volume -DriveLetter C -Defrag -ReTrim -SlabConsolidate -Verbose
##After windows update, clear out caches and merge patches in to windows
Do { $i++ ; & DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase } while($i -ne 5) 
##Clear recovery - this gets readded after sysprep
Remove-Item -Path C:\Recovery -Force -Recurse -Confirm:$false
##Clear autounattend logs
Remove-Item -Path C:\Windows\Panther -Force -Recurse -Confirm:$false
##Remove windows updates downloads
Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false

##Remove windows update manifestcache - abit hax. This wont be needed after /resetbase
& cmd.exe /c Takeown /f %windir%\winsxs\ManifestCache\*
& cmd.exe /c Icacls %windir%\winsxs\ManifestCache\* /GRANT administrators:F
& cmd.exe /c Del /q %windir%\winsxs\ManifestCache\*

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
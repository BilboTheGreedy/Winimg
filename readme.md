


## Prepare Build Host

### Prerequisites

* Install Windows Server 2016
* Download and run [ConfigureRemotingForAnsible.ps1](https://github.com/ansible/ansible/blob/devel/examples/scripts/ConfigureRemotingForAnsible.ps1)
* Configure any extra disks/volumes to be used

### Apply Configuration
Run playbook "prepare-host". This will do a couple of things
* Install Hyper-v
* Install DHCP
* Configure Virtual Interface/Switch with IP 192.168.0.1
* Configure NAT so hosts on 192.168.0.0/24 is reachable
* Install GIT & Clone Repository
* Trust all winrm clients on here

After it has completed, build server is now ready.

## Windows Iso
Windows iso is defined in vars file 'windows_iso.yml' and selected depending on set {{os_version}} variable.

iso will be downloaded and stored at {{ISOPath}} if {{http_fileserver}} is set to http url, set to 'skip' to ignore downloading.

## Secondary Iso
Secondary iso is required for unattended installation of Windows on UEFI since floppy drive is not supported.
Iso will be created by role: prepare-build. It will update the git repo and create a new secondary iso each time the build is started. iso output will be in git-path\build\OS\secondary.iso

### Autounattend.xml
Templated from jinja2 template in prepare-build role
vars set in autounattend_setup.yml
### Boostrap.ps1
Copied from scripts/setup. This will configure winrm and rdp at startup.
### Cloudbase-init.conf
Templated from jinja2 template in prepare-build role
vars set in cloudbase_vars.yml


## Image Process 

#### Overview

##### Prepare Build
1. Template autounattend.xml
2. Template cloudbase-int.conf
3. Add startup script
4. Create secondary iso
##### Build Image
1. Create dynamic disk in path: {{OutputPath}}{{os_selection}}
2. Create new G2 VM, select NATSwitch and VHDX created in step 1
3. Add Windows ISO & Secondary ISO
4. Boot VM
5. Wait for Boot
6. Type Boot Command
7. Wait for OS install completion
8. Get VM adapter IP
9. Wait for System to be ready - bootstrap.ps1
##### Online Operations
1. Run Windows Update
2. Download & Install latest Cloudbase-init. Find and copy config from Secondary.iso
3. Clean up image with dism
4. Finalize & Sysprep with cloudbase-init unattend.
##### Offline Operations
1. Remove VM. Clean up & Compact disk
##### Convert Image (Optional)
1. Create temporary clone of image
2. add virtio drivers & Convert disk qemu-img
3. Clean up temporary image
##### Upload Image
1. Upload disk for QA
2. ?

## PS Modules
Since we are working with double hop, modules for certain tasks can help enable remote functionality/automation of guests on build hosts.

### RemoteConfig.psm1
* "Invoke-CloudbaseInit" = Install and configure Cloudbase-init agent
* "Invoke-Finalize" = Clean up remnants of Autounattend, clear logs and sysprep image


### RemoteWindowsUpdate.psm1
This module will run a series of complex powershell jobs on the build host to update target Guest with latest Windows Updates. It will retry/Reboot untill a "true" response is given. When true, all updates found is installed.*
* "Invoke-WindowsUpdate" 

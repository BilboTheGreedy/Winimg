# Packer Templates

Tested and validated with Hyper-v 2016 and packer v1.3.3


# Folder structure

In the root you will find hyper-v json templates for packer. Working directory should be here always.

├───bin  <-- contains qemu-img 
├───build <-- template.yaml will output here for each os_version
│   ├───win2012r2dc
│   ├───win2012r2std
│   ├───win2016dc
│   └───win2016std
├───output-hyperv-iso <-- output directory for packer (default)
├───packer_cache <-- cache for iso etc
├───scripts 
│   └───common <-- used during provisioning stage
│   └───setup <-- scripts added to secondary.iso
├───templates <-- j2 templates
└───vars <-- vars file for template.yaml




## Setting up Hyper-v build host 

1. Install Windows Server 2016 Standard or Datacenter, if VM make sure nested virtualization is enabled/allowed
2. Install Hyper-v role
3. Add Internal Switch, set IP of virtual interface and add NAT 
`New-VMSwitch  -SwitchName  “NATSwitch”  -SwitchType  Internal`
`New-NetIPAddress  -IPAddress  192.168.0.1  -PrefixLength  24  -InterfaceAlias  “vEthernet  (NATSwitch)”`
`New-NetNAT  -Name  “NATNetwork”  -InternalIPInterfaceAddressPrefix  192.168.0.0/24`
4. Deploy minimal linux server with DHCP service on the "NATSwitch"
5. Clone repo to some sensible location (c:\packer for example)
6. Download packer and plugins binaries
7. Add ISO to iso/ (c:\packer\iso) Not required but recommended (packer can download ISOs from any given URL)
8. Get the hash for the ISO (Get-FileHash c:\iso\en_winX.iso)
9. Edit json template variable iso_checksum or run packer with -var "iso_checksum=*chksum*"
10. Edit json template variable iso_url or run packer with -var "iso_url=*path/url*"


## Plugins
Plugins for windows is either placed in `%APPDATA%/packer.d/plugins` or in same folder as packer.exe

### plugins list
* Windows Update - [packer-provisioner-windows-update](https://github.com/rgl/packer-provisioner-windows-update) 

## Template.yaml

Since this is written for ansible, you will need to enable linux subsystem on windows. Alternativly run this from another host and push content to the build server.
WS2016 build 16215+ and newer support linux subsystem feature. 

[Installing Linux subsystem on Windows](https://docs.microsoft.com/en-us/windows/wsl/install-on-server)

You only need the secondary.iso files in respective os_version path in build directory. Example build/win2016std/secondary.iso

Secondary iso will contain Autounattend.xml and bootstrap.ps1.

It's fully possible to build isos with powershell alone together with mkisofs for windows, however since Ansible will be able to run sort-of natively on Windows, the better option is to use Ansible for its templating feature. With subsystem enabled, you can access windows volume on /mnt/c from terminal.

## Using Proxy server 
If build environment is behind a proxy server for internet access, you can set VM to use one.
Set it in the same pass as the set-proxy.ps1 script is provisioned. To revert proxy settings, simply run another powershell provisioner pass with the same script later in the script.

````
      {
        "type": "powershell",
         "elevated_user":"{{ user `username`}}",
         "elevated_password":"{{ user `password`}}",
	 "environment_vars": [
        	"UseProxy=$True",
        	"Proxyserver=http://10.52.161.200:800"
        ],
        "scripts": [
         "{{template_dir}}/scripts/common/set-proxy.ps1",
         "{{template_dir}}/scripts/common/cloudbase-install.ps1"

        ]
      },
````


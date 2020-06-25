## Getting started

On the provisioner

* Copy `image.img` to the web root of nginx

* Then run:

```sh
./create_images.sh
```

* Then create the ubuntu.tmpl template with tink-cli

```
tink template create -n 'ubuntu' -p /tmp/ubuntu.tmpl
```

* Now create the hardware entry

```
tink hardware push --file /tmp/hw1.json 
```
* Now create a workflow for the entry with the template ID

```
# See the output from Terraform
export MAC="08:00:27:00:00:01"

# See tink template list
export TEMPLATE_ID="93de9281-d28a-4e9e-b8d8-8162d197b15f"
tink workflow create -t "$TEMPLATE_ID" -r '{"device_1": "'$MAC'"}'
```

* Boot up the worker


## Appendix

Make an image with Packer and Virtual box

Run:

```
VBoxManage clonehd ./packer-ubuntu-20.04-live-server-1593009318-disk001.vmdk image.img --format raw
```

This creates image.img - copy that to misc/osie/current/


### Packer

```
{
  "builders": [
    {
      "disk_size": "10000",
      "boot_command": [
        "<enter><enter><f6><esc><wait> ",
        "autoinstall ds=nocloud-net;seedfrom=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
        "<enter><wait>"
      ],
      "boot_wait": "5s",
      "format": "ovf",
      "headless": true,
      "http_directory": "http",
      "iso_checksum": "sha256:caf3fd69c77c439f162e2ba6040e9c320c4ff0d69aad1340a514319a9264df9f",
      "iso_urls": [
        "iso/ubuntu-20.04-live-server-amd64.iso",
        "https://releases.ubuntu.com/20.04/ubuntu-20.04-live-server-amd64.iso"
      ],
      "memory": 1024,
      "name": "ubuntu-20.04-live-server",
      "output_directory": "output/live-server",
      "shutdown_command": "sudo shutdown -P now",
      "ssh_handshake_attempts": "60",
      "ssh_password": "ubuntu",
      "ssh_pty": true,
      "ssh_timeout": "50m",
      "ssh_username": "ubuntu",
      "type": "virtualbox-iso",
      "guest_os_type": "Ubuntu_64"
    }
  ],
  "provisioners": [
    {
      "inline": [
        "ls /"
      ],
      "type": "shell"
    }
  ]
}
```

ubuntu.json

Empty file:

```
```

./http/meta-data

User-data

```
#cloud-config
autoinstall:
  version: 1
  locale: en_US
  keyboard:
    layout: en
    variant: us
  network:
    network:
      version: 2
      ethernets:
        ens33:
          dhcp4: true
  storage:
    layout:
      name: lvm
  identity:
    hostname: ubuntu
    username: ubuntu
    password: $6$rounds=4096$8dkK1P/oE$2DGKKt0wLlTVJ7USY.0jN9du8FetmEr51yjPyeiR.zKE3DGFcitNL/nF1l62BLJNR87lQZixObuXYny.Mf17K1
  ssh:
    install-server: yes
  user-data:
    disable_root: false
  late-commands:
    - 'sed -i "s/dhcp4: true/&\n      dhcp-identifier: mac/" /target/etc/netplan/00-installer-config.yaml'
    - echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/ubuntu
```

./http/user-data

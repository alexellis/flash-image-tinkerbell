# tink-workflow

With this step-by-step guide, you have everything you need to provision a bare-metal server using the [Tinkerbell project](https://tinkerbell.org).

## Getting Started

### Prerequisites

1. Get two machine, one is provisioner which it could be VM, the other one if the bare metal server you'd like to be 
provisioned by tinkerbell, here we call it worker node.

[Use the Tinkerbell Terraform module to setup a single provisioner and worker machine](https://tinkerbell.org/setup/packet-with-terraform/)

You will need a Packet account and a personal user access token, not a project-level token.

2. You need setup the tinkerbell provision engine before working on the workflow.

```bash
curl -sLS https://raw.githubusercontent.com/tinkerbell/tink/master/setup.sh | sh
```

### Fix NAT

```bash

# Fix Docker from interfering with NAT
# https://docs.docker.com/network/iptables/
iptables -I DOCKER-USER -i src_if -o dst_if -j ACCEPT

# Now setup NAT from the internal network to the public network
# https://www.revsys.com/writings/quicktips/nat.html
iptables -t nat -A POSTROUTING -o bond0 -j MASQUERADE
iptables -A FORWARD -i bond0 -o enp1s0f1 -m state   --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i enp1s0f1 -o bond0 -j ACCEPT 
```

### Build workflow action docker images

Customise the cloud-init stage with an SSH key from the provisioner.

Run `ssh-keygen` on the provisioner, then hit enter to each prompt.

Now run `cat ~/.ssh/id_rsa.pub` and paste the value into the `ssh_authorized_keys` section of `./05-cloud-init/cloud-init.sh`:

```yaml
		ssh_authorized_keys:
		 - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8TlZp6SMhZ3OCKxWbRAwOsuk8alXapXb7GQV4DPwZ+ug1AtkDCSSzPGZI6PP3rFILfobQdw6/t/GT3TKwQ1HY2vYqikWXG7YjT6r5IlsaaZ6y3KAuestYx2lG8I+MCbLmvcjo4k2qeJuf2yj331izRkeNRlRx/VWFUAtoCw2Kr2oZK+LbV8Ewv+x6jMVn9+NgxmMj+fHj9ajVtDacVvyJ8cStmRmOyIGd+rPKDb8txJT4FYXIsy5URhioni7QQuJcXN/qqy4TSY+EaYkGUo2j91MuDJZbdQYniOV4ODS8At/a/Ua51x+ia6Y51pCHMvPsm7DFhK13EQUXhIGdPVY3 root@tf-provisioner
```

Customise the network adapter name as per the environment in the `./05-cloud-init/cloud-init.sh` file:

* Packet - `enp1s0f0`
* On-premises - `eno1`
* Vagrant - `enp0s8`

Each image from 00-07 will be created as a Docker image and then pushed to the registry.

```bash
./create_images.sh
```

### Build provision images for worker

Archives will be required for:
* rootfs
* kernel
* modules
* initrd

Since we are using Packet's infrastructure, we can also use their image builder and custom repository.

A Docker build will be run to reproduce for tar.gz files which need to be copied into Nginx's root, where OSIE will serve them to the worker.

The initial Terraform uses the c3.small.x86 worker type, so use the following parameters to configure Ubuntu 18.04.

```bash
# Elevate to root privileges

sudo -i

#

apt update && apt install -qy git git-lfs fakeroot jq
git clone https://github.com/packethost/packet-images && \
  cd packet-images && \
  git-lfs install
```

Optional step if using Vagrant instead of Packet's infrastructure:

Edit the `./tools/get-ubuntu-image` file with nano or vim and add `:80` to the `+gpg --keyserver` line.

Or run a sed command:

```
sed -ie s/keyservers.net/keyservers.net:80/ tools/get-ubuntu-image
```

```
diff --git a/tools/get-ubuntu-image b/tools/get-ubuntu-image
index cd983e031..40d4a6757 100755
--- a/tools/get-ubuntu-image
+++ b/tools/get-ubuntu-image
@@ -25,7 +25,7 @@ path="http://cdimage.ubuntu.com/ubuntu-base/releases/$version/release"
 file=ubuntu-base-$fullversion-base-$arch.tar.gz
 
 echo "Fetching keys"
-gpg --keyserver hkp://ha.pool.sks-keyservers.net --recv-keys \
+gpg --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys \
        843938DF228D22F7B3742BC0D94AA3F0EFE21092 \
        C5986B4F1257FFA86632CBA746181433FBB75451
```

Now run this to build the image:

```
# This will take a few minutes
./tools/build.sh -d ubuntu_18_04 -p c3.small.x86 -a x86_64 -b ubuntu_18_04-c3.small.x86
```

### Deploy images

#### Packet users

```bash
# ls -l /var/tinkerbell/nginx/misc/osie/current/ubuntu_18_04/
total 397756                                                                                    
-rw-r--r-- 1 root root 278481368 May 19 08:54 image.tar.gz                                      
-rw-r--r-- 1 root root  25380938 May 19 08:54 initrd.tar.gz                                     
-rw-r--r-- 1 root root   7896480 May 19 08:54 kernel.tar.gz                                     
-rw-r--r-- 1 root root  65386698 May 19 08:54 modules.tar.gz                                    

# Now copy the output so that it's available to be served over HTTP
mkdir -p /var/tinkerbell/nginx/misc/osie/current/ubuntu_18_04
cp *.tar.gz /var/tinkerbell/nginx/misc/osie/current/ubuntu_18_04/
```

#### Vagrant users

Take note that users of Vagrant will find the Nginx root directory available at `/usr/share/nginx` instead of `/var/tinkerbell/nginx`.

```bash
# ls -l ./work/ubuntu_18_04-c3.small.x86/
total 397756                                                                                    
-rw-r--r-- 1 root root 278481368 May 19 08:54 image.tar.gz                                      
-rw-r--r-- 1 root root  25380938 May 19 08:54 initrd.tar.gz                                     
-rw-r--r-- 1 root root   7896480 May 19 08:54 kernel.tar.gz                                     
-rw-r--r-- 1 root root  65386698 May 19 08:54 modules.tar.gz                                    

# Now copy the output so that it's available to be served over HTTP
mkdir -p /vagrant/deploy/state/webroot/misc/osie/current/ubuntu_18_04

# Make the individual archives:
./tools/archive-ubuntu ./ubuntu_18_04-c3.small.x86-image.tar.gz ./

mv ubuntu_18_04-c3.small.x86-image.tar.gz image.tar.gz
cp ./*.tar.gz /vagrant/deploy/state/webroot/misc/osie/current/ubuntu_18_04/
```

#### Internal Equinix use only

Internal Equinix users can run, however this is not recommended for general use.

```bash
# 1. git-lfs
apt-get install git-lfs
#2. get-ubuntu-image
wget https://raw.githubusercontent.com/packethost/packet-images/master/tools/get-ubuntu-image
#3. make get-ubuntu-image executable
chmod +x get-ubuntu-image
#4. packet-save2image
wget https://raw.githubusercontent.com/packethost/packet-images/master/tools/packet-save2image
#5. set packet-save2image to executable
chmod +x packet-save2image
#6. Download Dockerfile
wget https://raw.githubusercontent.com/packethost/packet-images/ubuntu_18_04-base/x86_64/Dockerfile
#7. Download Image:
./get-ubuntu-image 16.04 x86_64 .
#8. Build:
docker build -t custom-ubuntu-16 .
#9. Save
docker save custom-ubuntu-16 > custom-ubuntu-16.tar
#10. Package:
./packet-save2image < custom-ubuntu-16.tar > image.tar.gz
```

### Register the hardware

At this point you can exit the root shell and return to a normal user.

1. Download this repo to your provisioner

2. Use `vim` to modify the `generate.sh` file to create the `hw1.json` file for your baremetal server

For Vagrant users the worker machine's MAC address is `08:00:27:00:00:01`

```bash
#!/bin/bash

export UUID=$(uuidgen|tr "[:upper:]" "[:lower:]")  #UUID will be generated by uuidgen
export MAC=b8:59:9f:e0:f6:8c     # Change this MAC address to your worker node PXE port mac address, it has to match.
```

Now run `./generate.sh` to create the `hardware.json` file which contains the MAC address and a unique UUID.

3. Login into tink-cli client and push hw1.json and ubuntu.tmpl into tink
You need copy both hw1.json and ubuntu.tmpl file to tink cli before you can push them into tink

3.1 Create hardware

```bash
# Run the CLI from within Docker
docker exec -it deploy_tink-cli_1 sh

# push the hardware information to tink database
tink hardware push --file /tmp/hw1.json
```

### Create the template and workflow

1. Create workflow template

```bash
# Save ubuntu.tmpl to a file /tmp/ubuntu.tmpl

# Create a template based upon the output
tink template create -n 'ubuntu' -p /tmp/ubuntu.tmpl
```

1.1 Create workflow

```bash
# See the output from Terraform
export MAC="<MAC of your worker PXE port>"

# See tink template list
export TEMPLATE_ID="<template-uuid>"
tink workflow create -t "$TEMPLATE_ID" -r '{"device_1": "'$MAC'"}'
```

### Reboot worker

For Packet and on-premises reboot the worker node. This will trigger workflow and you can monitor it using the `tink workflow events` command.

For Vagrant users, run `vagrant up worker` instead.

```
/tmp #  tink workflow events f588090f-e64b-47e9-b8d0-a3eed1dc5439
+--------------------------------------+-----------------+-----------------+----------------+---------------------------------+--------------------+
| WORKER ID                            | TASK NAME       | ACTION NAME     | EXECUTION TIME | MESSAGE                         |      ACTION STATUS |
+--------------------------------------+-----------------+-----------------+----------------+---------------------------------+--------------------+
| 90e16ddd-a4ce-4591-bb91-3ec1eddd0e2b | os-installation | disk-wipe       |              0 | Started execution               | ACTION_IN_PROGRESS |
| 90e16ddd-a4ce-4591-bb91-3ec1eddd0e2b | os-installation | disk-wipe       |              7 | Finished Execution Successfully |     ACTION_SUCCESS |
| 90e16ddd-a4ce-4591-bb91-3ec1eddd0e2b | os-installation | disk-partition  |              0 | Started execution               | ACTION_IN_PROGRESS |
| 90e16ddd-a4ce-4591-bb91-3ec1eddd0e2b | os-installation | disk-partition  |             12 | Finished Execution Successfully |     ACTION_SUCCESS |
| 90e16ddd-a4ce-4591-bb91-3ec1eddd0e2b | os-installation | install-root-fs |              0 | Started execution               | ACTION_IN_PROGRESS |
| 90e16ddd-a4ce-4591-bb91-3ec1eddd0e2b | os-installation | install-root-fs |              8 | Finished Execution Successfully |     ACTION_SUCCESS |
| 90e16ddd-a4ce-4591-bb91-3ec1eddd0e2b | os-installation | install-grub    |              0 | Started execution               | ACTION_IN_PROGRESS |
| 90e16ddd-a4ce-4591-bb91-3ec1eddd0e2b | os-installation | install-grub    |              5 | Finished Execution Successfully |     ACTION_SUCCESS |
+--------------------------------------+-----------------+-----------------+----------------+---------------------------------+--------------------+
```

Important note: if you need to re-run the provisioning workflow, you need to run `tink workflow create` again.

Vagrant users will want to open the VirtualBox app and increase the Display scaling size to 300% if they are using a 4k or Retina display.

### Did something go wrong?

If anything appears to go wrong, you can log into the OSIE environment which was netbooted.

* Login with `root` (no password)
* Run `docker ps -a` to find the exited Docker container for the Tinkerbell worker
* Run `docker logs CONTAINER_ID` where CONTAINER_ID is the whole name, or a few characters from the container ID

Or in a single command: `docker logs $(docker ps -qa|head -n1)`

Once you've determined the error, create a new workflow again with `tink workflow create` and reboot the worker.

If you're using Vagrant, for the time being you will need to run: `vagrant destroy worker --force && vagrant up worker`.

### Change the boot order

You now need to stop the machine from netbooting.

#### Packet

Go to the Packet dashboard and click "Server Actions" -> "Disable Always PXE boot". This setting can be toggled as required, or if you need to reprovision a machine.

Now reboot the worker machine, and it should show GRUB before booting Ubuntu.

#### On-premises / at-home or with Vagrant

Now reboot the worker machine, and it should show GRUB before booting Ubuntu. Hit `e` for edit, and remove the text `console=ttyS0, 115200` and hit the key to continue booting (F10)

If you do not do this, then you will not be able to see the computer boot up and you won't be able to log in to `tty0` through VirtualBox.

### Login in for the first time

The username and password are both `ubuntu` and this must be changed on first logon. To change the initial password or to remove the default password, you can edit `./05-cloud-init/cloud-init.sh` and run `./create-images.sh` again, then re-provision the host.

You can connect with the packet SOS ssh console or over SSH from the worker, the IP should be 192.168.1.5.

```bash
ssh ubuntu@192.168.1.5
```

## Questions and comments

Please direct queries to #tinkerbell on [Packet's Slack channel](https://slack.packet.com/)

## Authors

This work is derived [from a sample by Packet and Infracloud](https://github.com/tinkerbell/tink/tree/first-good-workflow/workflow-samples/ubuntu)

* **Alex Ellis** - Fixed networking and other bugs, user experience & README. Steps for Vagrant.
* **Xin Wang** - *Initial set of fixes and adding cloud-init* - [tink-workflow](https://github.com/wangxin311/tink-workflow)

License: Apache 2.0

Copyright: [tink-workflow authors](https://github.com/wangxin311/tink-workflow/graphs/contributors)
# flash-image-tinkerbell

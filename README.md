<!--
SPDX-FileCopyrightText: 2026-2026 Franco Masotti (See /README.md)

SPDX-License-Identifier: MIT
-->

# Cockpit virtual machines setup

<a href="https://www.buymeacoffee.com/frnmst" target="_blank"><img src="https://img.shields.io/badge/-buy_me_a%C2%A0coffee-gray?logo=buy-me-a-coffee" alt="Buy Me A Coffee"></a>

Documentation to run a fully functional virtual machine environment via Cockpit
on Debian hosts, including networking, clipboard support, deterministic SPICE
ports, encrypted remote SPICE viewing, etc.

<!--TOC-->

- [Cockpit virtual machines setup](#cockpit-virtual-machines-setup)
  - [Description](#description)
  - [Prerequisites](#prerequisites)
    - [Dependencies](#dependencies)
    - [NetworkManager](#networkmanager)
  - [Configuration](#configuration)
    - [Networking](#networking)
    - [Storage](#storage)
    - [Remote viewing with SPICE](#remote-viewing-with-spice)
      - [Set a static port](#set-a-static-port)
      - [Increase GPU memory](#increase-gpu-memory)
      - [Usage via SSH](#usage-via-ssh)
        - [virsh configuration](#virsh-configuration)
        - [Local configuration](#local-configuration)
      - [Viewing](#viewing)
      - [Clipboard support](#clipboard-support)
        - [Debian guests](#debian-guests)
        - [Windows guests](#windows-guests)
  - [References](#references)
  - [Contributing, changelog and security](#contributing-changelog-and-security)
  - [Consulting and custom integrations](#consulting-and-custom-integrations)
  - [License](#license)
  - [Git forge mirrors](#git-forge-mirrors)
  - [Support this project](#support-this-project)
<!-- TOC by https://github.com/frnmst/md-toc ver. 9.1.0 -->

<!--TOC-->

## Description

Cockpit is an open source system dashboard by Redhat which supports various
plugins including a virtual machine manager.

By the end of this tutorial you will be able to run your virtual machines
within Cockpit so that:

- machines are exposed on the same network as the host
- machines have a static SPICE port to enable remote desktop access in a
  deterministic way
- machines have SPICE clipboard support
- remote desktop will be reactive thanks to video compression
- machines have enhanced GPU memory
- you will be able to connect to the machine via SPICE using an encrypted
  SSH tunnel

Follow the steps in order, top to bottom.

> [!IMPORTANT]
> Server-side steps have been tested on Debian 12 and 13 systems. You might
> need to make some adjustments.

## Prerequisites

### Dependencies

Install the dependencies

```shell
apt install cockpit cockpit-machines cockpit-networkmanager lastlog2
```

> [!IMPORTANT]
> `lastlog2` is needed in case you get an installation error error like:
>
> ```
> cockpit creating vm: VM does not exist on system connection
> ```
>
> If you check the browser developer tools with F12 you might notice this:
>
> ```
> /var/lib/lastlog/lastlog2.db does not exist
> ```

### NetworkManager

To be able to have virtual machines on the same network as the host, yout
must use a bridge networking device. Cockpit can manage network devices via
NetworkManager, an open source Red Hat product.

NetworkManager needs to be able to manage all network connections. It is
assumed here that `networking.service` is managing the ethernet device. In this
document the default physical ethernet device is called `eno1`: check yours
with:

```shell
ip a
```

1. set NetworkManager to handle interfaces listed in `/etc/network/interaces`.
   Use this key-value in `/etc/NetworkManager/NetworkManager.conf`:

   ```
   [ifupdown]
   managed=true
   ```

2. restart NetworkManager and reload the connections

   ```shell
   systemctl restart NetworkManager
   nmcli connection reload
   ```

3. open nmui

   ```shell
   nmtui
   ```

4. you should now see the ethernet physical networking device
5. comment everything inside `/etc/networking/interfaces` and disable `networking.service`

   ```shell
   systemctl disable networking.service
   systemctl enable NetworkManager.service
   ```

6. if you use special rules via post-up or similar, remember to place them in
   the NetworkManager's configurations
7. reboot
8. if needed, re-configure the network interface via `nmtui`
9. open the
   [Cockpit `Networking` admin page](http://127.0.0.1:9090/machines#/networks)
   and check if the bridge is now editable

## Configuration

### Networking

In the Cockpit web UI, create a bridge network within Cockpit.

1. open the `Networking` tab
2. click on `Add bridge`:
   - `Name`: `br0`
   - `Ports`: check `eno1`
3. the original `eno1` device should disappear from the global list of network
   devices; `br0` inherits information from `eno1`

If you use iptables, you need to make all traffic forwardable. Other firewalls
might use different commands.

1. open a root shell on the host operating system and make ``iptables``
   properly route traffic to the bridge:

   ```shell
   iptables -A FORWARD -o br0 -j ACCEPT
   iptables -A FORWARD -i br0 -j ACCEPT
   ip6tables -A FORWARD -o br0 -j ACCEPT
   ip6tables -A FORWARD -i br0 -j ACCEPT
   ```

2. save the new iptables configuration persistently:

   ```shell
   iptables-save > /etc/iptables/rules.v4
   ip6tables-save > /etc/iptables/rules.v6
   ```

### Storage

By default, Cockpit (virsh) uses `/var/lib/libvirt` to hold virtual machine
images and other data. In the next point you'll see how to move the storage
to a different (dedicated) partition

1. create a destination directory on the host machine so that it is accessible
   by the `libvrt-qemu` user and group. As long as the partition holding the
   directory has enough free space for planned usage, you might do something
   like this:

   ```shell
   mkdir /cockpit-machines \
       && chown libvrt-qemu:libvrt-qemu /cockpit-machines \
       && chmod 700 /cockpit-machines
   ```

   `/cockpit-machines` can be on a dedicated fast partition mounted in that+
   path. If your root is small, avoid using this directly

2. stop all the virtual machine services

   ```shell
   systemctl stop libvirt* cockpit
   ```

3. create a bind mount to the default location. This will hugely simply the
   storage pool management. Add the following to `/etc/fstab`:

   ```fstab
   /cockpit-machines /var/lib/libvirt none auto,bind
   ```

   This means that `/cockpit-machines` will be mounted on `/var/lib/libvirt`

4. copy the existing data to the new location and remove the original

   ```shell
   cd /cockpit-machines \
       && rsync --dry-run -avAX /var/lib/libvirt/ . \
       && read \
       && rsync -avAX /var/lib/libvirt/ .
   cd /var/lib/libvirt \
       && rm -rf boot dnsmasq images qemu
   ```

5. enable the bind mount

   ```shell
   systemctl daemon-reload
   mount -a
   ```

6. restart the services

   ```shell
   systemctl start --all libvirt* cockpit
   ```

7. open the [storage pools](http://127.0.0.1:9090/machines#/storages) page: you
   should now see the `default` storage pool (`/var/lib/libvirt/images`) with
   the same size as `/cockpit-machines`

### Remote viewing with SPICE

SPICE is an alternative to VNC when it comes to remote viewing. By default,
Cockpit uses VNC in the browser window. By using SPICE, however, things like
clipboard sharing seem much easier.

Finally, you should use an encrypted tunnel via SSH to protect your data if
interaction is done on another machine.

#### Set a static port

Having a static SPICE port is useful if you want to actually use SPICE with
fixed profiles on third-party clients. If you use the default configuration
and other machines are managed, you risk having to re-configure the connection
profiles. Cockpit/virsh, in fact, dynamically selects free SPICE ports for
virtual machines. Since we don't know *a-priori* which port will be chosen for
other VMs, we'll use for example port 5950. These kinds of ports usually start
from 5900.

1. open a shell on the guest and edit the virtual machine XML manifest
   The machine name is the same as the one used in Cockpit web UI:

   ```shell
   virsh edit --domain my_virtual_machine
   ```

2. find this section:

   ```xml
   <graphics type='spice' autoport='yes' listen='127.0.0.1'>
     <listen type='address' address='127.0.0.1'/>
     <image compression='off'/>
   </graphics>
   ```

   and change it like this:

   ```xml
   <graphics type='spice' port='5950' autoport='no' listen='127.0.0.1'>
     <listen type='address' address='127.0.0.1'/>
     <image compression='off'/>
   </graphics>
   ```

3. stop and restart the virtual machine

#### Increase GPU memory

1. open a shell on the guest and edit the virtual machine XML manifest
   The machine name is the same as the one used in Cockpit web UI:

   ```shell
   virsh edit --domain my_virtual_machine
   ```

2. find a section very similar to this one:

   ```xml
   <video>
     <model type='qxl' ram='262144' vram='262144' vgamem='65536' heads='1' primary='yes'/>
     ...
   </video>
   ```

   change it to the following to have up to 512 MB of GPU memory:

   ```xml
   <video>
     <model type='virtio' vram='524288' heads='1' primary='yes'/>
     ...
   </video>
   ```

#### Usage via SSH

##### virsh configuration

When using remotely via SSH, even in gigabit LAN environments, graphics
compression is required for a smooth experience, at the cost of some artifacts

1. open a shell on the guest and edit the virtual machine XML manifest
   The machine name is the same as the one used in Cockpit web UI:

   ```shell
   virsh edit --domain my_virtual_machine
   ```

2. find the SPICE graphics section and replace it like this:

   ```xml
   <graphics type='spice' port='5950' autoport='no' listen='127.0.0.1'>
     <listen type='address' address='127.0.0.1'/>
     <image compression='quic'/>
     <jpeg compression='always'/>
     <zlib compression='always'/>
     <playback compression='on'/>
     <streaming mode='filter'/>
   </graphics>
   ```

3. stop and restart the virtual machine

##### Local configuration

To be able to connect from another computer easily, you should use something
like [autossh](https://www.harding.motd.ca/autossh/) to create a tunnel.

In this example we assume the remote server running virtual machines and ssh
is called `my.remote.server` and the user we're connecting to is `user`. We can
redirect any number of remote ports locally, but in this example there are
three: `5950`, `5951`, and `5952`. To simplify things we set the same remote
ports matching local ones:

- `5950` remote == `5950` local
- `5951` remote == `5951` local
- `5952` remote == `5952` local

1. on the server check that you have these options enabled in
   `/etc/ssh/sshd_config`. You can enable them per single user only:

   ```ini
   AllowTcpForwarding yes
   PermitTunnel yes
   ```

   This option can only be applied globally:

   ```ini
   TCPKeepAlive yes
   ```

2. on the remote viewer computer, install autossh with your package manager

   ```shell
   apt install autossh
   ```

3. create a new Systemd service that runs autossh in
   `/etc/systemd/system/autossh-vm.service`. The local running user is
   `localuser`:

   ```ini
   [Unit]
   Description=AutoSSH service for virtual machine SPICE ports
   After=network.target

   [Service]
   User=localuser
   Group=localuser
   Environment="AUTOSSH_GATETIME=0"
   ExecStart=/usr/bin/autossh -M 0 -N -L 0.0.0.0:5950:127.0.0.1:5950 -L 0.0.0.0:5951:127.0.0.1:5951 -L 0.0.0.0:5952:127.0.0.1:5952 -o TCPKeepAlive=yes user@my.remote.server

   [Install]
   WantedBy=multi-user.target
   ```

4. enable and start the service

   ```shell
   systemctl enable --now autossh-vm.service
   ```

#### Viewing

Any client that support SPICE should do. You can try both
[Remmina](https://remmina.org/) and
[virt-viewer](https://virt-manager.org/index.html)

> [!TIP]
> You can share local USB devices with the virtual machine in one click with
> SPICE.

#### Clipboard support

Using a remote desktop without clipboard support is very inconvenient. If you
are able to copy and paste text you will save time sharing information.

##### Debian guests

1. install the addons. For debian guests systems:

   ```shell
   apt install spice-vdagent
   ```

2. Add the run agent command to `~/.xinitrc`

   ```shell
   echo '/usr/bin/spice-vdagent &' >> ~/.xinitrc
   ```

3. reboot the virtual machine

##### Windows guests

Windows has its own addons. Install them from the
[SPICE website](https://www.spice-space.org/download.html#windows-binaries)

All you need to do is to download and run the
[installer](https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe),
then reboot.

## References

- [Cockpit Project](https://cockpit-project.org/)
- [Managing virtual machines with Cockpit](https://docs.fedoraproject.org/en-US/fedora-server/virtualization/vm-management-cockpit/)
- [Network Bridge Operation not Supported · Issue #543 · cockpit-project/cockpit-machines](https://github.com/cockpit-project/cockpit-machines/issues/543)
- [ssh into the guest · cockpit-project/cockpit-machines · Discussion #1907 · GitHub](https://github.com/cockpit-project/cockpit-machines/discussions/1907)
- [Cockpit: NewtorkManager](https://cockpit-project.org/guide/latest/feature-networkmanager)

## Contributing, changelog and security

- [CONTRIBUTING](./CONTRIBUTING.md)
- [CHANGELOG](./CHANGELOG.md)
- [SECURITY](./SECURITY.md)

## Consulting and custom integrations

If you are an organization, enterprise or an individual relying on cockpit-virtual-machines-setup and
need help or custom integrations for other parsers or feature development, I'm
available for contract-based freelance consulting:

- Email: <solvecomputersciencecollabs+cockpit-virtual-machines-setup@gmail.com>
- Freelancing: <https://blog.franco.net.eu.org/jobs/>

## License

These files are used with minor changes in other repositories but with
different licenses.

Copyright (c) 2026 Franco Masotti (See `./README.md`).

## Git forge mirrors

| URL | Type | Notes |
|-----|------|-------|
| https://github.com/frnmst/cockpit-virtual-machines-setup | RW | Official home |
| https://codeberg.org/frnmst/cockpit-virtual-machines-setup | RW | Mirror |
| https://framagit.org/frnmst/cockpit-virtual-machines-setup | RW | Mirror |
| https://repos.franco.net.eu.org/frnmst/cockpit-virtual-machines-setup | RW | Mirror |

## Support this project

- [GitHub Sponsors](https://github.com/sponsors/frnmst)
- [Buy Me a Coffee](https://www.buymeacoffee.com/frnmst)
- [Liberapay](https://liberapay.com/frnmst)

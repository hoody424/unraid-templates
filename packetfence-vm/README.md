# PacketFence VM for Unraid

[PacketFence](https://www.packetfence.org/) is an open source network access
control (NAC) system: 802.1X/RADIUS, captive portal, VLAN assignment, device
profiling. Template: [packetfence-vm.xml](packetfence-vm.xml), image:
`ghcr.io/hoody424/packetfence-vm` (source in [image/](image/)).

PacketFence does not run as a Docker container. It brings its own DHCP, DNS,
RADIUS and firewall and expects a whole machine. The vendor ships it as the
ZEN appliance, a ready-made VMware VM. This container is an installer, like
Macinabox: it turns that appliance into a normal VM in the Unraid VM tab and
stops.

## What the container does

1. Finds the newest PacketFence release that has a ZEN appliance, or the
   version you set.
2. Uses `PacketFence-ZEN-v<version>.zip` from the Downloads or VM storage
   folder if it is already there, otherwise downloads it (about 8 GB) and
   checks the MD5.
3. Unpacks zip → OVA → VMDK and converts the VMDK with `qemu-img` into
   `<VM storage>/<VM name>/vdisk1.img`.
4. Creates the VM through libvirt (Debian, SeaBIOS, Q35, virtio disk and
   network, VNC console) and starts it.

Running the container again does nothing while a VM with that name exists.
To start over, remove the VM in the VM tab with **Remove VM & Disks**. If only
the VM definition is gone but the vdisk is still there, the container reuses
the vdisk.

## Requirements

- VMs enabled: Settings > VM Manager.
- For the VM: 4 cores and 16 GB of memory (PacketFence's minimum).
- During the import: about 40 GB free in the VM storage. The vdisk is 200 GB
  thin-provisioned and uses about 21 GB at first.

## Settings

| Setting | Default | Meaning |
|---|---|---|
| VM name | `PacketFence` | Name in the VM tab and folder name in the VM storage |
| PacketFence version | `latest` | Or a version such as `15.2.0` |
| CPU cores / Memory (GB) | `4` / `16` | VM size, editable later in the VM tab |
| Network | `br0` | Bridge for the network card: `br0`, `br0.10` (VLAN 10) or `vhost0`. Start with one card, as PacketFence's guide says; `br0,br0.10` adds a second one |
| MAC address | empty | Fixed MAC for the first card, e.g. for a DHCP server that only serves known MACs. Empty = random; the log shows it |
| VNC keyboard | `en-us` | Keyboard layout of the console, for example `de` |
| Start VM / VM autostart | `yes` / `no` | |
| VM storage | `/mnt/user/domains/` | Your VM storage path |
| Downloads | `/mnt/user/isos/` | Where the zip is stored |
| Source file (advanced) | empty | Your own `.zip`, `.ova` or `.vmdk` (container path) or a URL |
| Vdisk type / bus (advanced) | `raw` / `virtio` | |

The container needs the libvirt socket (to create the VM) and reads its own
mounts through the Docker socket, read-only, to know the host path of the VM
storage. The PacketFence icon is copied to
`/boot/config/plugins/dynamix.vm.manager/templates/images`, where Unraid
looks for custom VM icons.

## First start of the VM

1. Open the VM's VNC console in the VM tab. The first network card gets its
   address by DHCP.
2. Console login: `root` / `p@ck3tf3nc3`. Change this password. `ip a` shows
   the address.
3. Open `https://<VM address>:1443` and go through the configurator
   (network, admin account, Fingerbank key). The appliance runs the QEMU
   guest agent, so **Open WebUI** in the VM's menu in the VM tab opens this
   page once the VM has an address.

See the [PacketFence Installation Guide](https://www.packetfence.org/doc/PacketFence_Installation_Guide.html)
for the configuration that follows (switches, RADIUS, Active Directory).

## Support

- Template and installer problems: [issues](https://github.com/hoody424/unraid-templates/issues)
- PacketFence itself: [inverse-inc/packetfence](https://github.com/inverse-inc/packetfence/issues)

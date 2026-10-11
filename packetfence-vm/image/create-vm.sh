#!/bin/bash
# Creates a PacketFence ZEN virtual machine in the Unraid VM manager, then exits.
#
# 1. finds the ZEN appliance (local file or official download, MD5-checked)
# 2. unpacks zip -> ova -> vmdk and converts the vmdk into an Unraid vdisk
# 3. writes the VM definition into libvirt, so it shows up in the VM tab
#
# Running it again never touches an existing VM or vdisk.
set -euo pipefail
shopt -s inherit_errexit

VM_NAME="${VM_NAME:-PacketFence}"
PF_VERSION="${PF_VERSION:-latest}"
SOURCE="${SOURCE:-}"
CPUS="${CPUS:-4}"
RAM_GB="${RAM_GB:-16}"
NETWORK="${NETWORK:-br0}"
MAC_ADDRESS="${MAC_ADDRESS:-}"
VDISK_TYPE="${VDISK_TYPE:-raw}"
VDISK_BUS="${VDISK_BUS:-virtio}"
VNC_KEYMAP="${VNC_KEYMAP:-en-us}"
START_VM="${START_VM:-yes}"
AUTOSTART="${AUTOSTART:-no}"
KEEP_DOWNLOAD="${KEEP_DOWNLOAD:-yes}"
DOMAINS_HOST_PATH="${DOMAINS_HOST_PATH:-}"

ZEN_BASE="https://us-ord-1.linodeobjects.com/packetfence-zen"
RELEASES_API="https://api.github.com/repos/inverse-inc/packetfence/releases?per_page=10"
LIBVIRT_SOCK="/var/run/libvirt/libvirt-sock"
VIRSH=(virsh -q -c "qemu:///system?socket=$LIBVIRT_SOCK")

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; exit 1; }
yes_set() { [[ "${1,,}" =~ ^(yes|true|1|y)$ ]]; }

check_settings() {
  [[ "$VM_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "VM name '$VM_NAME': use letters, digits, '.', '_' and '-' only"
  [[ "$CPUS" =~ ^[1-9][0-9]*$ ]] || die "CPU cores '$CPUS' is not a number"
  [[ "$RAM_GB" =~ ^[1-9][0-9]*$ ]] || die "Memory '$RAM_GB' is not a number of GB"
  [[ "$VDISK_TYPE" =~ ^(raw|qcow2)$ ]] || die "Vdisk type must be raw or qcow2"
  [[ "$VDISK_BUS" =~ ^(virtio|sata|scsi)$ ]] || die "Vdisk bus must be virtio, sata or scsi"
  [[ "$NETWORK" =~ ^[A-Za-z0-9._-]+(,[A-Za-z0-9._-]+)*$ ]] || die "Network '$NETWORK': bridge names separated by commas, no spaces"
  [[ -z "$MAC_ADDRESS" || "${MAC_ADDRESS,,}" =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]] || die "MAC address '$MAC_ADDRESS' is not like 52:54:00:12:34:56"
  [[ "$VNC_KEYMAP" =~ ^[a-z]{2}(-[a-z]{2,3})?$ ]] || die "VNC keyboard '$VNC_KEYMAP' is not a keymap such as en-us or de"
  (( RAM_GB >= 16 )) || log "Note: PacketFence needs at least 16 GB of memory; with $RAM_GB GB services may fail to start."
}

check_host() {
  [ -S "$LIBVIRT_SOCK" ] || die "No libvirt socket at $LIBVIRT_SOCK. Enable VMs (Settings > VM Manager) and keep the 'libvirt' path mapping."
  "${VIRSH[@]}" version >/dev/null || die "Cannot talk to libvirt through $LIBVIRT_SOCK"
  [ -d /domains ] && [ -w /domains ] || die "/domains (VM storage) is not mapped or not writable"
}

# Host path behind a container path, read from this container's own mounts
host_path_of() {
  local id
  id=$(grep -o 'containers/[0-9a-f]\{64\}' /proc/self/mountinfo | head -n1 | cut -d/ -f2 || true)
  [ -n "$id" ] || id=$(hostname)
  curl -sf --unix-socket /var/run/docker.sock "http://localhost/containers/$id/json" \
    | jq -r --arg d "$1" '.Mounts[] | select(.Destination == $d) | .Source' 2>/dev/null || true
}

resolve_version() {
  if [ "$PF_VERSION" != "latest" ]; then
    echo "${PF_VERSION#v}"
    return
  fi
  local tags tag
  tags=$(curl -sf "$RELEASES_API" | jq -r '.[] | select(.draft or .prerelease | not) | .tag_name' 2>/dev/null || true)
  for tag in $tags; do
    if curl -sfI -o /dev/null "$ZEN_BASE/$tag/PacketFence-ZEN-$tag.zip"; then
      echo "${tag#v}"
      return
    fi
  done
  # offline: newest appliance already on disk
  find /downloads /domains -maxdepth 1 -name 'PacketFence-ZEN-v*.zip' 2>/dev/null \
    | sed -n 's/.*PacketFence-ZEN-v\(.*\)\.zip$/\1/p' | sort -V | tail -n1 || true
}

# Prints the space used by a growing file or folder every 30 s while process $1 runs
report_progress() {
  local pid=$1 file=$2 total=${3:-0} size
  while kill -0 "$pid" 2>/dev/null; do
    sleep 30
    [ -e "$file" ] || continue
    size=$(( $(du -sk "$file" | cut -f1) << 10 ))
    if (( total > 0 )); then
      log "  $(( size * 100 / total ))% ($(( size >> 20 )) of $(( total >> 20 )) MiB)"
    else
      log "  $(( size >> 20 )) MiB written"
    fi
  done
}

# Downloads $1 to $2 (resumes a .part file), sets DOWNLOADED
fetch() {
  local url=$1 dest=$2 total pid
  mkdir -p "$(dirname "$dest")"
  total=$(curl -sfIL "$url" | tr -d '\r' | awk 'tolower($1) == "content-length:" { n = $2 } END { print n + 0 }' || true)
  if (( total > 0 )); then
    log "Downloading $url ($(( total >> 20 )) MiB)"
  else
    log "Downloading $url"
  fi
  curl -fsSL --retry 5 --retry-delay 15 -C - -o "$dest.part" "$url" &
  pid=$!
  report_progress "$pid" "$dest.part" "$total" &
  wait "$pid" || die "Download failed. Start the container again to resume."
}

download_zen() {
  local version=$1
  local name="PacketFence-ZEN-v$version.zip"
  local url="$ZEN_BASE/v$version/$name"
  local part="/downloads/$name.part" md5
  curl -sfI -o /dev/null "$url" || die "PacketFence $version has no ZEN appliance at $url"
  fetch "$url" "/downloads/$name"
  md5=$(curl -sf "$url.md5sums.txt" | awk 'NR == 1 { print $1 }' || true)
  if [ -n "$md5" ]; then
    log "Checking MD5"
    echo "$md5  $part" | md5sum -c --status || { rm -f "$part"; die "MD5 mismatch, download removed. Start the container again."; }
  fi
  mv "$part" "/downloads/$name"
  DOWNLOADED="/downloads/$name"
}

find_source() {
  if [ -n "$SOURCE" ]; then
    if [[ "$SOURCE" =~ ^https?:// ]]; then
      local name
      name=$(basename "${SOURCE%%\?*}")
      if [ ! -f "/downloads/$name" ]; then
        fetch "$SOURCE" "/downloads/$name"
        mv "/downloads/$name.part" "/downloads/$name"
        DOWNLOADED="/downloads/$name"
      fi
      SRC="/downloads/$name"
    else
      [ -f "$SOURCE" ] || die "Source file $SOURCE not found inside the container (use a path under /downloads or /domains)"
      SRC="$SOURCE"
    fi
    return
  fi
  local version f
  version=$(resolve_version)
  [ -n "$version" ] || die "Cannot find the latest PacketFence version (no internet?). Set the PacketFence version or a source file."
  for f in "/downloads/PacketFence-ZEN-v$version.zip" "/domains/PacketFence-ZEN-v$version.zip"; do
    if [ -f "$f" ]; then
      log "Using existing $f"
      SRC="$f"
      return
    fi
  done
  download_zen "$version"
  SRC="$DOWNLOADED"
}

# Unpacks the vmdk from $SRC into $WORK, sets VMDK
unpack() {
  local inner
  case "${SRC,,}" in
    *.ova)
      bsdtar -xf "$SRC" --no-same-owner -C "$WORK" '*.vmdk' ;;
    *.zip)
      inner=$(bsdtar -tf "$SRC" | awk 'tolower($0) ~ /\.(ova|vmdk)$/ && !n++')
      [ -n "$inner" ] || die "$SRC contains no .ova or .vmdk"
      if [[ "${inner,,}" == *.ova ]]; then
        bsdtar -xOf "$SRC" "$inner" | bsdtar -xf - --no-same-owner -C "$WORK" '*.vmdk'
      else
        bsdtar -xf "$SRC" --no-same-owner -C "$WORK" "$inner"
      fi ;;
    *)
      die "Unsupported source $SRC (expected .zip, .ova or .vmdk)" ;;
  esac
}

extract_vmdk() {
  local pid
  if [[ "${SRC,,}" == *.vmdk ]]; then
    VMDK="$SRC"
    return
  fi
  log "Unpacking the disk from $(basename "$SRC")"
  unpack &
  pid=$!
  report_progress "$pid" "$WORK" &
  wait "$pid" || die "Unpacking $SRC failed"
  VMDK=$(find "$WORK" -iname '*.vmdk' -print -quit)
}

create_vdisk() {
  local pid free_gb
  free_gb=$(( $(df -Pk /domains | awk 'NR == 2 { print $4 }') >> 20 ))
  (( free_gb >= 40 )) || die "Only $free_gb GB free under /domains; the import needs about 40 GB."
  find_source
  WORK="$VM_DIR/.import"
  rm -rf "$WORK"
  mkdir -p "$WORK"
  extract_vmdk
  [ -n "${VMDK:-}" ] && [ -f "$VMDK" ] || die "No .vmdk found in $SRC"
  log "Converting $(basename "$VMDK") to a $VDISK_TYPE vdisk"
  qemu-img convert -f vmdk -O "$VDISK_TYPE" "$VMDK" "$WORK/vdisk1.img" &
  pid=$!
  report_progress "$pid" "$WORK/vdisk1.img" &
  wait "$pid" || die "qemu-img convert failed"
  mv "$WORK/vdisk1.img" "$VDISK"
  rm -rf "$WORK"
  if [ -n "${DOWNLOADED:-}" ] && ! yes_set "$KEEP_DOWNLOAD"; then
    log "Removing download $DOWNLOADED"
    rm -f "$DOWNLOADED"
  fi
  chown -R 99:100 "$VM_DIR" 2>/dev/null || true
  log "vdisk ready: $(qemu-img info --output=json "$VDISK" \
    | jq -r '"\(.["virtual-size"] / 1073741824 | floor) GiB, \(.["actual-size"] / 107374182.4 | floor / 10) GiB used"')"
}

# MAC address setting for the first card, random ones otherwise
mac_address() {
  if [ "$1" = 1 ] && [ -n "$MAC_ADDRESS" ]; then
    echo "${MAC_ADDRESS,,}"
    return
  fi
  printf '52:54:00:%02x:%02x:%02x' $(( RANDOM % 256 )) $(( RANDOM % 256 )) $(( RANDOM % 256 ))
}

domain_xml() {
  local uuid machine icon="debian.png" bus_xml controller_xml="" interfaces="" br n=0
  uuid=$(cat /proc/sys/kernel/random/uuid)
  machine=$("${VIRSH[@]}" capabilities | grep -o 'pc-q35-[0-9.]*[0-9]' | sort -uV | tail -n1)
  [ -n "$machine" ] || machine="q35"
  if [ -d /icons ] && cp /app/packetfence.png /icons/packetfence.png 2>/dev/null; then
    icon="packetfence.png"
  fi
  bus_xml="<target dev='hdc' bus='$VDISK_BUS'/>"
  if [ "$VDISK_BUS" = "scsi" ]; then
    controller_xml="<controller type='scsi' index='0' model='virtio-scsi'/>"
  fi
  for br in ${NETWORK//,/ }; do
    n=$(( n + 1 ))
    if [[ "$br" =~ ^vhost[0-9]+(\.[0-9]+)?$ ]]; then
      interfaces+="
    <interface type='direct' trustGuestRxFilters='yes'>
      <mac address='$(mac_address "$n")'/>
      <source dev='$br' mode='bridge'/>
      <model type='virtio-net'/>
    </interface>"
    else
      interfaces+="
    <interface type='bridge'>
      <mac address='$(mac_address "$n")'/>
      <source bridge='$br'/>
      <model type='virtio-net'/>
    </interface>"
    fi
  done
  cat <<EOF
<domain type='kvm'>
  <name>$VM_NAME</name>
  <uuid>$uuid</uuid>
  <description>PacketFence ZEN $PF_LABEL (created by the packetfence-vm container)</description>
  <metadata>
    <vmtemplate xmlns="unraid" name="Debian" icon="$icon" os="debian" webui="https://[IP]:1443/" storage="default"/>
  </metadata>
  <memory unit='KiB'>$(( RAM_GB * 1048576 ))</memory>
  <currentMemory unit='KiB'>$(( RAM_GB * 1048576 ))</currentMemory>
  <memoryBacking>
    <nosharepages/>
  </memoryBacking>
  <vcpu placement='static'>$CPUS</vcpu>
  <os>
    <type arch='x86_64' machine='$machine'>hvm</type>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='1' dies='1' clusters='1' cores='$CPUS' threads='1'/>
    <cache mode='passthrough'/>
  </cpu>
  <clock offset='utc'>
    <timer name='hpet' present='no'/>
    <timer name='hypervclock' present='no'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='rtc' tickpolicy='catchup'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <devices>
    <emulator>/usr/local/sbin/qemu</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='$VDISK_TYPE' cache='writeback' discard='unmap'/>
      <source file='$VDISK_HOST'/>
      $bus_xml
      <serial>vdisk1</serial>
      <boot order='1'/>
    </disk>
    $controller_xml$interfaces
    <serial type='pty'>
      <target type='isa-serial' port='0'>
        <model name='isa-serial'/>
      </target>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <channel type='unix'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
    </channel>
    <input type='tablet' bus='usb'/>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' websocket='-1' listen='0.0.0.0' keymap='$VNC_KEYMAP'>
      <listen type='address' address='0.0.0.0'/>
    </graphics>
    <audio id='1' type='none'/>
    <video>
      <model type='qxl' ram='65536' vram='16384' vgamem='16384' heads='1' primary='yes'/>
    </video>
    <memballoon model='virtio'/>
  </devices>
</domain>
EOF
}

main() {
  check_settings
  check_host

  if "${VIRSH[@]}" dominfo "$VM_NAME" >/dev/null 2>&1; then
    log "VM '$VM_NAME' already exists ($("${VIRSH[@]}" domstate "$VM_NAME")). Nothing to do."
    log "To start over, remove it in the VM tab with 'Remove VM & Disks' and start this container again."
    exit 0
  fi

  local domains_host
  domains_host="${DOMAINS_HOST_PATH:-$(host_path_of /domains)}"
  [ -n "$domains_host" ] || die "Cannot find the host path of /domains. Map /var/run/docker.sock or set 'VM storage host path'."
  domains_host="${domains_host%/}"

  VM_DIR="/domains/$VM_NAME"
  VDISK="$VM_DIR/vdisk1.img"
  VDISK_HOST="$domains_host/$VM_NAME/vdisk1.img"
  PF_LABEL="$PF_VERSION"
  mkdir -p "$VM_DIR"

  if [ -f "$VDISK" ]; then
    log "Reusing existing vdisk $VDISK_HOST"
  else
    create_vdisk
    PF_LABEL=$(basename "$SRC" | sed -n 's/.*-v\([0-9][0-9.]*[0-9]\).*/v\1/p')
    PF_LABEL="${PF_LABEL:-$PF_VERSION}"
  fi

  local xml="$VM_DIR/.domain.xml"
  domain_xml > "$xml"
  "${VIRSH[@]}" define "$xml" >/dev/null || die "libvirt refused the VM definition (kept in $xml)"
  rm -f "$xml"
  log "VM '$VM_NAME' created: $CPUS cores, $RAM_GB GB, disk $VDISK_HOST"
  "${VIRSH[@]}" domiflist "$VM_NAME" | awk 'NF >= 5 { print "  network card on " $3 ", MAC " $5 }'

  if yes_set "$AUTOSTART"; then
    "${VIRSH[@]}" autostart "$VM_NAME" >/dev/null && log "Autostart enabled"
  fi
  if yes_set "$START_VM"; then
    "${VIRSH[@]}" start "$VM_NAME" >/dev/null && log "VM started"
  fi

  log "Next: open the VM's VNC console in the VM tab. The first network card gets its address by DHCP;"
  log "log in as root / p@ck3tf3nc3 and run 'ip a' if the console doesn't show it."
  log "Then open https://<VM address>:1443 and go through the configurator. Change the root password."
  log "This container's work is done; it can stay stopped or be removed."
}

main "$@"

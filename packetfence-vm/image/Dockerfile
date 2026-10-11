FROM alpine:3.24

RUN apk add --no-cache bash ca-certificates coreutils curl jq libarchive-tools libvirt-client qemu-img tzdata

COPY create-vm.sh packetfence.png /app/
RUN chmod 755 /app/create-vm.sh

LABEL org.opencontainers.image.title="packetfence-vm" \
      org.opencontainers.image.description="Creates a PacketFence ZEN virtual machine in the Unraid VM manager" \
      org.opencontainers.image.source="https://github.com/hoody424/unraid-templates" \
      org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/app/create-vm.sh"]

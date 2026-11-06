#cloud-config
hostname: __NAME__
manage_etc_hosts: true
ssh_pwauth: true
chpasswd:
  expire: false
  users:
    - {name: ubuntu, password: ubuntu, type: text}
ssh_authorized_keys:
  - __PUBKEY__
packages:
  - qemu-guest-agent
runcmd:
  - systemctl enable --now qemu-guest-agent

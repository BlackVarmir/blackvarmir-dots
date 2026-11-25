#!/usr/bin/env bash
# shellcheck disable=SC2034
# Профіль archiso для BlackVarmir Arch. Збирається через iso/build.sh.

iso_name="blackvarmir-arch"
iso_label="BVARCH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="BlackVarmir <https://github.com/BlackVarmir/blackvarmir-dots>"
iso_application="BlackVarmir Arch live and installer"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
# Лише UEFI: двосистемна установка поруч із Windows на GPT-диску все одно потребує UEFI
bootmodes=('uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d/10-live"]="0:0:440"
  ["/usr/local/bin/blackvarmir-live-session"]="0:0:755"
  ["/usr/local/bin/blackvarmir-installer"]="0:0:755"
)

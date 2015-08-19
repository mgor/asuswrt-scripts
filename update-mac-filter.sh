#!/usr/bin/env sh

log_message() {
  message="$1"
  logger -s -p user.info -t update-mac-filter "$message"
}

username="router"
hostname="dhcp.example.com"
dhcpd_conf="/etc/dhcpd.conf"
identity="/jffs/scripts/ssh/id_rsa"

ap_wl_maclist_x=$(nvram get wl0_maclist_x)
dhcpd_wl_maclist_x=""

# Fetch MAC addresses from DHCP server configuration
# TODO: Ignore lines with comments?
for tuple in $(ssh -y -y -i $identity $username@$hostname "egrep 'host|ethernet' $dhcpd_conf | sed 'N;s/\n/ /' | awk '{print \$6\$2}' | sort")
do
  client=$(echo $tuple | awk -F\; '{print "<"toupper($1)">"$2}')
  count=$(echo $ap_wl_maclist_x | grep -c $client)

  test $count -lt 0 && log_message "Adding $client"

  dhcpd_wl_maclist_x="${dhcpd_wl_maclist_x}${client}"
done

# Check if some MAC address is removed
for tuple in $(nvram get wl0_maclist_x | sed 's/</\n</g')
do
  test "x$tuple" == "x" && continue

  count=$(echo $dhcpd_wl_maclist_x | grep -c $tuple)

  test $count -lt 1 && log_message "Removing ${tuple}"
done


# No changes don't do anything
test "x${ap_wl_maclist_x}" == "x${dhcpd_wl_maclist_x}" && exit 0

# Add all mac addresses to both mac lists
for i in 0 1
do
  nvram set wl_unit=${i}
  nvram set wl${i}_maclist_x="${dhcpd_wl_maclist_x}"
  nvram set wl_maclist_x="${dhcpd_wl_maclist_x}"
  
  test "$(nvram get x_Setting)" -eq 0 && nvram set x_Setting=1
  test "$(nvram get w_Setting)" -eq 0 && nvram set w_Setting=1

  nvram commit
done

# Needed for the changes to take effect
service restart_wireless

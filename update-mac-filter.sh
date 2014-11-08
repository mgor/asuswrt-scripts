#!/usr/bin/env sh

log_message() {
  message="$1"
  logger -t update-mac-filter "$message"
  logger -s -t update-mac-filter "$message"
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
  if [ $count -lt 0 ]
  then
    log_message "Adding $client"
  fi
  dhcpd_wl_maclist_x="${dhcpd_wl_maclist_x}${client}"
done

# Check if some MAC address is removed
for tuple in $(nvram get wl0_maclist_x | sed 's/</\n</g')
do
  if [ "x$tuple" == "x" ]
  then
    continue
  fi

  count=$(echo $dhcpd_wl_maclist_x | grep -c $tuple)

  if [ $count -lt 1 ]
  then
    log_message "Removing $tuple"
  fi
done


# No changes don't do anything
if [ "x${ap_wl_maclist_x}" == "x${dhcpd_wl_maclist_x}" ]
then
  exit 0
fi

# Add all mac addresses to both mac lists
for i in 0 1
do
  nvram set wl_unit=${i}
  nvram set wl${i}_maclist_x="${dhcpd_wl_maclist_x}"
  nvram set wl_maclist_x="${dhcpd_wl_maclist_x}"
  if [ "$(nvram get x_Setting)" -eq 0 ]
  then
    nvram set x_Setting=1
  fi

  if [ "$(nvram get w_Setting)" -eq 0 ]
  then
    nvram set w_Setting=1
  fi

  nvram commit
done

# Needed for the changes to take effect
service restart_wireless

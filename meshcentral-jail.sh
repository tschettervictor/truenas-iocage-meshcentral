#!/bin/sh
# Build an iocage jail under TrueNAS 13.0 using the current release of MeshCentral
# git clone https://github.com/tschettervictor/truenas-iocage-meshcentral

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

#####
#
# General configuration
#
#####

# Initialize defaults
JAIL_IP=""
JAIL_INTERFACES=""
DEFAULT_GW_IP=""
INTERFACE="vnet0"
VNET="on"
POOL_PATH=""
DATA_PATH=""
FILES_PATH=""
BACKUPS_PATH=""
JAIL_NAME="meshcentral"
HOST_NAME=""
CONFIG_NAME="meshcentral-config"
DATABASE="mongodb"
DB_NAME="meshcentral"
DB_USER="meshcentral"
DB_ROOT_PASSWORD=$(openssl rand -base64 15)
DB_PASSWORD=$(openssl rand -base64 15)

# Check for meshcentral-config and set configuration
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "${SCRIPT}")
if ! [ -e "${SCRIPTPATH}"/"${CONFIG_NAME}" ]; then
  echo "${SCRIPTPATH}/${CONFIG_NAME} must exist."
  exit 1
fi
. "${SCRIPTPATH}"/"${CONFIG_NAME}"
INCLUDES_PATH="${SCRIPTPATH}"/includes

JAILS_MOUNT=$(zfs get -H -o value mountpoint $(iocage get -p)/iocage)
RELEASE=$(freebsd-version | cut -d - -f -1)"-RELEASE"
# If release is 13.1-RELEASE, change to 13.2-RELEASE
if [ "${RELEASE}" = "13.1-RELEASE" ]; then
  RELEASE="13.2-RELEASE"
fi 

#####
#
# Input/Config Sanity checks
#
#####

# Check that necessary variables were set by meshcentral-config
if [ -z "${JAIL_IP}" ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z "${JAIL_INTERFACES}" ]; then
  echo 'JAIL_INTERFACES not set, defaulting to: vnet0:bridge0'
JAIL_INTERFACES="vnet0:bridge0"
fi
if [ -z "${DEFAULT_GW_IP}" ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z "${POOL_PATH}" ]; then
  echo 'Configuration error: POOL_PATH must be set'
  exit 1
fi
if [ -z "${HOST_NAME}" ]; then
  echo 'Configuration error: HOST_NAME must be set'
  exit 1
fi

# If DATA_PATH, FILES_PATH, and BACKUPS_PATH weren't set, set them
if [ -z "${DATA_PATH}" ]; then
  DATA_PATH="${POOL_PATH}"/meshcentral/data
fi
if [ -z "${FILES_PATH}" ]; then
  FILES_PATH="${POOL_PATH}"/meshcentral/files
fi
if [ -z "${BACKUPS_PATH}" ]; then
  BACKUPS_PATH="${POOL_PATH}"/meshcentral/backups
fi

# Sanity check DATA_PATH, FILES_PATH, BACKUPS_PATH, and POOL_PATH
if [ "${DATA_PATH}" = "${FILES_PATH}" ] || [ "${DATA_PATH}" = "${BACKUPS_PATH}" ] || [ "${DATA_PATH}" = "${POOL_PATH}" ] || [ "${FILES_PATH}" = "${BACKUPS_PATH}" ] || [ "${FILES_PATH}" = "${POOL_PATH}" ] || [ "${BACKUPS_PATH}" = "${POOL_PATH}" ]
then
  echo "DATA_PATH, FILES_PATH, BACKUPS_PATH and POOL_PATH must be different"
  exit 1
fi

# Extract IP and netmask, sanity check netmask
IP=$(echo ${JAIL_IP} | cut -f1 -d/)
NETMASK=$(echo ${JAIL_IP} | cut -f2 -d/)
if [ "${NETMASK}" = "${IP}" ]
then
  NETMASK="24"
fi
if [ "${NETMASK}" -lt 8 ] || [ "${NETMASK}" -gt 30 ]
then
  NETMASK="24"
fi

#####
#
# Jail Creation
#
#####

# List packages to be auto-installed after jail creation
cat <<__EOF__ >/tmp/pkg.json
{
  "pkgs": [
  "nano",
  "npm-node20",
  "node20"
  ]
}
__EOF__

# Create the jail and install previously listed packages
if ! iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r "${RELEASE}" interfaces="${JAIL_INTERFACES}" ip4_addr="${INTERFACE}|${IP}/${NETMASK}" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}"
then
	echo "Failed to create jail"
	exit 1
fi
rm /tmp/pkg.json

#####
#
# Directory Creation and Mounting
#
#####

mkdir -p "${POOL_PATH}"/meshcentral/data
mkdir -p "${POOL_PATH}"/meshcentral/files
mkdir -p "${POOL_PATH}"/meshcentral/backups
iocage exec "${JAIL_NAME}" mkdir -p /usr/local/meshcentral/meshcentral-data
iocage exec "${JAIL_NAME}" mkdir -p /usr/local/meshcentral/meshcentral-files
iocage exec "${JAIL_NAME}" mkdir -p /usr/local/meshcentral/meshcentral-backups
iocage exec "${JAIL_NAME}" mkdir -p /mnt/includes
iocage exec "${JAIL_NAME}" mkdir -p /usr/local/etc/rc.d
iocage exec "${JAIL_NAME}" mkdir -p /var/run/meshcentral
iocage fstab -a "${JAIL_NAME}" "${DATA_PATH}" /usr/local/meshcentral/meshcentral-data nullfs rw 0 0
iocage fstab -a "${JAIL_NAME}" "${FILES_PATH}" /usr/local/meshcentral/meshcentral-files nullfs rw 0 0
iocage fstab -a "${JAIL_NAME}" "${BACKUPS_PATH}" /usr/local/meshcentral/meshcentral-backups nullfs rw 0 0
iocage fstab -a "${JAIL_NAME}" "${INCLUDES_PATH}" /mnt/includes nullfs rw 0 0

#####
#
# MeshCentral Install
#
#####

iocage exec "${JAIL_NAME}" "pw user add meshcentral -c meshcentral -u 6374 -s /usr/bin/nologin -d /home"
iocage exec "${JAIL_NAME}" "cd /usr/local/meshcentral && npm install meshcentral"
iocage exec "${JAIL_NAME}" "chown -R meshcentral:meshcentral /usr/local/meshcentral"
iocage exec "${JAIL_NAME}" "chown -R meshcentral:meshcentral /var/run/meshcentral"
iocage exec "${JAIL_NAME}" cp -f /mnt/includes/meshcentral /usr/local/etc/rc.d/
iocage exec "${JAIL_NAME}" sysrc meshcentral_enable="YES"
iocage exec "${JAIL_NAME}" service meshcentral start && sleep 5

# Don't need /mnt/includes any more, so unmount it
iocage fstab -r "${JAIL_NAME}" "${INCLUDES_PATH}" /mnt/includes nullfs rw 0 0

iocage restart "${JAIL_NAME}"

echo "---------------"
echo "Installation complete."
echo "---------------"
echo "Using your web browser, go to https://${HOST_NAME} to start setup"
echo "---------------"

# truenas-iocage-meshcentral
Script to create an iocage jail on TrueNAS for the latest MeshCentral release.

This script will create an iocage jail on TrueNAS CORE 13.0 with the latest release of MeshCentral, along with its dependencies. It will configure the jail to store the data and files outside the jail, so it will not be lost in the event you need to rebuild the jail.

## Status
This script will work with TrueNAS CORE 13.0

## Usage

### Prerequisites (Datasets)
You will need to create 
- 1 Dataset named `meshcentral`
- 3 subdatasets named `data` `files` and `backups` underneath the above
If these are not present, a directory `/meshcentral` will be created in `$POOL_PATH` with the obove mentioned subdirectories. You will want to create the datasets, otherwise the directories will just be created. Datasets make it easy to do snapshots etc...

### Installation
Download the repository to a convenient directory on your TrueNAS system by changing to that directory and running `git clone https://github.com/tschettervictor/truenas-iocage-meshcentral`.  Then change into the new `truenas-iocage-meshcentral` directory and create a file called `meshcentral-config` with your favorite text editor.  In its minimal form, it would look like this:
```
JAIL_IP="192.168.1.199"
DEFAULT_GW_IP="192.168.1.1"
POOL_PATH="/mnt/tank"
HOST_NAME="YOUR_FQDN"
```
Many of the options are self-explanatory, and all should be adjusted to suit your needs, but only a few are mandatory.  The mandatory options are:

* JAIL_IP is the IP address for your jail.  You can optionally add the netmask in CIDR notation (e.g., 192.168.1.199/24).  If not specified, the netmask defaults to 24 bits.  Values of less than 8 bits or more than 30 bits are invalid.
* DEFAULT_GW_IP is the address for your default gateway
* POOL_PATH is the path for your data pool
* HOST_NAME is the hostname that will be assigned to you jail
 
In addition, there are some other options which have sensible defaults, but can be adjusted if needed.  These are:

* JAIL_NAME: The name of the jail, defaults to "meshcentral"
* DATA_PATH. This is the path to your database files. It defaults to POOL_PATH/meshcentral/data
* FILES_PATH. This is the path to meshcentral user files. It defaults to POOL_PATH/meshcentral/files
* BACKUPS_PATH. This is the path to server backups. It defaults to POOL_PATH/meshcentral/backups
* INTERFACE: The network interface to use for the jail.  Defaults to `vnet0`.
* JAIL_INTERFACES: Defaults to `vnet0:bridge0`, but you can use this option to select a different network bridge if desired.  This is an advanced option; you're on your own here.
* VNET: Whether to use the iocage virtual network stack.  Defaults to `on`.
  
### Execution
Once you've downloaded the script and prepared the configuration file, run this script (`script meshcentral.log ./meshcentral-jail.sh`).  The script will run for several minutes.  When it finishes, your jail will be created, MeshCentral will be installed, and you can go ahead and start setup.

### Notes
- Reinstalls work as expected when the previous data is present.
- Since Meshcentral will run as the meshcentral user, and low port binding is not allowed by users other thatn root, the default port that will be used is 1025.
- MeshCentral is extremely simple to install, but has many options and configurations available. These are all set in a config file located at `/usr/local/meshcentral/meshcentral-data/config.json`

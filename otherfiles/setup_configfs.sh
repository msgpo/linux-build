#!/bin/sh

# ConfigFS script is taken from postmarketOS
# https://postmarketos.org

# These are very important, it defines what is the device:

deviceinfo_usb_idVendor="0x1F3A"
deviceinfo_usb_idProduct="0xEFE8"
deviceinfo_manufacturer="Pine64"
deviceinfo_name="PinePhone"

# We'll let them know that this device is Arch ARM.
deviceinfo_usb_serialnumber="Arch ARM Pine64"

setup_usb_network_configfs() {
	# See: https://www.kernel.org/doc/Documentation/usb/gadget_configfs.txt
	CONFIGFS=/sys/kernel/config/usb_gadget/

	if ! [ -e "$CONFIGFS" ]; then
		echo "  $CONFIGFS does not exist, skipping configfs usb gadget"
		return
	fi

	# Default values for USB-related deviceinfo variables
	usb_idVendor="${deviceinfo_usb_idVendor:-0x18D1}"   # default: Google Inc.
	usb_idProduct="${deviceinfo_usb_idProduct:-0xD001}" # default: Nexus 4 (fastboot)
	usb_serialnumber="${deviceinfo_usb_serialnumber:-postmarketOS}"
	usb_rndis_function="${deviceinfo_usb_rndis_function:-rndis.usb0}"

	echo "  Setting up an USB gadget through configfs"
	# Create an usb gadet configuration
	mkdir $CONFIGFS/g1 || echo "  Couldn't create $CONFIGFS/g1"
	echo "$usb_idVendor"  > "$CONFIGFS/g1/idVendor"
	echo "$usb_idProduct" > "$CONFIGFS/g1/idProduct"

	# Create english (0x409) strings
	mkdir $CONFIGFS/g1/strings/0x409 || echo "  Couldn't create $CONFIGFS/g1/strings/0x409"

	# shellcheck disable=SC2154
	echo "$deviceinfo_manufacturer" > "$CONFIGFS/g1/strings/0x409/manufacturer"
	echo "$usb_serialnumber"        > "$CONFIGFS/g1/strings/0x409/serialnumber"
	# shellcheck disable=SC2154
	echo "$deviceinfo_name"         > "$CONFIGFS/g1/strings/0x409/product"

	# Create rndis function. The function can be named differently in downstream kernels.
	mkdir $CONFIGFS/g1/functions/"$usb_rndis_function" \
		|| echo "  Couldn't create $CONFIGFS/g1/functions/$usb_rndis_function"

	# Create configuration instance for the gadget
	mkdir $CONFIGFS/g1/configs/c.1 \
		|| echo "  Couldn't create $CONFIGFS/g1/configs/c.1"
	mkdir $CONFIGFS/g1/configs/c.1/strings/0x409 \
		|| echo "  Couldn't create $CONFIGFS/g1/configs/c.1/strings/0x409"
	echo "rndis" > $CONFIGFS/g1/configs/c.1/strings/0x409/configuration \
		|| echo "  Couldn't write configration name"

	# Link the rndis instance to the configuration
	ln -s $CONFIGFS/g1/functions/"$usb_rndis_function" $CONFIGFS/g1/configs/c.1 \
		|| echo "  Couldn't symlink $usb_rndis_function"

	# Check if there's an USB Device Controller
	if [ -z "$(ls /sys/class/udc)" ]; then
		echo "  No USB Device Controller available"
		return
	fi

	# Link the gadget instance to an USB Device Controller. This activates the gadget.
	# See also: https://github.com/postmarketOS/pmbootstrap/issues/338
	# shellcheck disable=SC2005
	echo "$(ls /sys/class/udc)" > $CONFIGFS/g1/UDC || echo "  Couldn't write UDC"
}

# And we go.
setup_usb_network_configfs
ip address add 172.16.42.1/24 dev usb0

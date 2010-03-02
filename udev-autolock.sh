#!/usr/bin/env bash
#
#   vim:ft=sh:fenc=UTF-8:ts=4:sts=4:sw=4:noexpandtab:foldmethod=marker:foldlevel=0:
#
#   Copyright (c) 2007 Wael Nasreddine <wael.nasreddine@gmail.com>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, 
#   USA.
#

####
# Configurations

if [ -f "/etc/udev-autolock.conf" ]; then
	source /etc/udev-autolock.conf
else
	echo "Configuration file not found. /etc/udev-autolock.conf"
	exit 1
fi

#
####

####
# Environment

ACTION="${1}"
DEVICE="/dev/${2}"

#
####

####
# Functions

function lockDown()
{
	# Lock X
	lockX

	# pause Mpd
	pauseMpd
}

function lockX()
{
	for USER in ${USERS[@]}; do
		# Get the PID of the running lockDown
		userId="$(id -u ${USER})"
		PID="$(pgrep -U ${userId} xlock)"
 
		# Check if a lock is already running
		if [ -n "${PID}" ]; then
			echo "Xlock already running with PID: ${PID}"
			return
		fi

		#if RunningX; then
			echo "Starting xlock for ${USER}"
			( DISPLAY=:0 su -l ${USER} -c '/usr/bin/xlock -mode matrix' & ) &> /dev/null
		#fi
	done
}

function pauseMpd()
{
	if mpc -h "${MPD_HOST}" -p "${MPD_PORT}" | grep -q '^\[playing\]'; then
		mpc -h "${MPD_HOST}" -p "${MPD_PORT}" pause

		rm -f /var/run/udev-autolock.mpd

		echo "MPD PAUSED" > /var/run/udev-autolock.mpd
	fi
}

function unlockDown()
{
	# Unlock X
	unlockX

	# play Mpd
	playMpd
}

function unlockX()
{
	for USER in ${USERS[@]}; do
		# Get the PID of the running lockDown
		userId="$(id -u ${USER})"
		PID="$(pgrep -U ${userId} xlock)"

		if [ -n "${PID}" ]; then
			kill -9 "${PID}" > /dev/null 2>&1
		fi
	done

}

function playMpd() {
	if [ -f /var/run/udev-autolock.mpd ]; then
		if [ "`cat /var/run/udev-autolock.mpd`" = "MPD PAUSED" ]; then
			mpc -h "${MPD_HOST}" -p "${MPD_PORT}" play
		fi

		rm -f /var/run/udev-autolock.mpd
	fi
}

#
####

####
# Main


# Make sure the sd modules
for i in sdhci sdhci_pci mmc_core mmc_block; do
	modprobe ${i} > /dev/null 2>&1
done

# Start the check
if [ "${ACTION}" == "remove" ]; then
	# The device has been removed, LOCKDOWN!
	echo "The device has been removed, calling lockDown."
	lockDown
elif [ "${ACTION}" == "add" ]; then
	echo "The device has been inserted, verifying the data."

	TEMP=`mktemp /tmp/secret.XXXX`

	# Read the secret key
	dd if=${DEVICE} of=${TEMP} bs=1 skip=${OFFSET} count=${SIZE} > /dev/null 2>&1

	NEW_SHA=`sha512sum ${TEMP} | awk '{print $1}'`

	shred --remove --zero ${TEMP}

	if [ "${SHA512}" != "${NEW_SHA}" ]; then
		# The device is not a device I'm aware of. LOCKDOWN!
		echo "The data are invalid, calling lockDown."
		lockDown
	else
		# The device is the *one* unlock everything
		echo "The data are valid, calling unlockDown."
		unlockDown
	fi
fi

#
####

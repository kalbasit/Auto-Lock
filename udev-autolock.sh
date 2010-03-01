#!/usr/bin/env bash
#
#   vim:ft=sh:fenc=UTF-8:ts=4:sts=4:sw=4:expandtab:foldmethod=marker:foldlevel=0:
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
# Environment

USER="wael"
ACTION="${1}"
DEVICE="/dev/${2}"
OFFSET=131072
SIZE=5120
#PID_FILE=/tmp/xlock.pid
SHA512="db5fddfa816dcf7620c13816337e236042103d58e01ec7bb05c6ae61e0a51eabdf7605f16f6681fe8a988823f2ff7f6361c9bd845dc0d1f87bb098463209b5d9"

#
####

####
# Functions

function lockDown()
{
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
}

function unlockDown()
{
    # Get the PID of the running lockDown
    userId="$(id -u ${USER})"
    PID="$(pgrep -U ${userId} xlock)"

    if [ -n "${PID}" ]; then
        kill -9 "${PID}" > /dev/null 2>&1
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
    lockDown
elif [ "${ACTION}" == "add" ]; then
    TEMP=`mktemp /tmp/secret.XXXX`

    # Read the secret key
    dd if=${DEVICE} of=${TEMP} bs=1 skip=${OFFSET} count=${SIZE} > /dev/null 2>&1

    NEW_SHA=`sha512sum ${TEMP} | awk '{print $1}'`

    shred --remove --zero ${TEMP}

    if [ "${SHA512}" != "${NEW_SHA}" ]; then
        # The device is not a device I'm aware of. LOCKDOWN!
        lockDown
    else
        # The device is the *one* unlock everything
        unlockDown
    fi
fi

#
####

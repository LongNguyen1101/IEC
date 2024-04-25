#!/bin/bash

echo "Enter repeat count"
read repeatCount
echo "Enter label"
read label

echo "Bit Rate,Tx-Power,Retry short limit,RTS thr,Fragment thr,Link Quality,Rx invalid nwid,Rx invalid crypt,Rx invalid frag,Tx excessive retries,Invalid misc,Missed beacon,Frequency,Channel,Encryption key,inactive time,tx bytes,authorized,authenticated,associated,WMM/WME,TDLS peer,DTIM period,beacon interval,short slot time,connection.autoconnect,connection.autoconnect-priority,connection.autoconnect-retries,connection.multi-connect,connection.auth-retries,connection.read-only,connection.zone,connection.master,connection.slave-type,connection.autoconnect-slaves,connection.secondaries,connection.gateway-ping-timeout,connection.mdns,connection.llmnr,connection.wait-device-timeout,802-11-wireless.band,802-11-wireless.channel,802-11-wireless.bssid,802-11-wireless.rate,802-11-wireless.tx-power,802-11-wireless.hidden,802-11-wireless.powersave,802-11-wireless.ap-isolation,802-11-wireless-security.wep-tx-keyidx,802-11-wireless-security.proto,802-11-wireless-security.pairwise,802-11-wireless-security.group,802-11-wireless-security.pmf,802-11-wireless-security.psk-flags,802-11-wireless-security.fils,ipv4.dns-priority,ipv4.route-metric,ipv4.route-table,ipv4.ignore-auto-routes,ipv4.ignore-auto-dns,ipv4.dhcp-iaid,ipv4.dhcp-timeout,ipv4.dhcp-send-hostname,ipv4.never-default,ipv4.may-fail,ipv4.dad-timeout,ipv6.route-metric,ipv6.ignore-auto-routes,ipv6.ignore-auto-dns,ipv6.never-default,ipv6.may-fail,ipv6.dhcp-timeout,GENERAL.DEFAULT,GENERAL.DEFAULT6,GENERAL.VPN,GENERAL.ZONE,GENERAL.MASTER-PATH,GENERAL.MTU,GENERAL.IP4-CONNECTIVITY,GENERAL.IP6-CONNECTIVITY,GENERAL.IS-SOFTWARE,GENERAL.NM-MANAGED,GENERAL.AUTOCONNECT,GENERAL.FIRMWARE-MISSING,GENERAL.NM-PLUGIN-MISSING,GENERAL.METERED,WIFI-PROPERTIES.WEP,WIFI-PROPERTIES.WPA,WIFI-PROPERTIES.WPA2,WIFI-PROPERTIES.TKIP,WIFI-PROPERTIES.CCMP,WIFI-PROPERTIES.AP,WIFI-PROPERTIES.ADHOC,WIFI-PROPERTIES.2GHZ,WIFI-PROPERTIES.5GHZ,WIFI-PROPERTIES.MESH,WIFI-PROPERTIES.IBSS-RSN,WE,Group Cipher,Pairwise Ciphers,Mode,connection.lldp,802-11-wireless.mode,802-11-wireless.mode,802-11-wireless.mode,802-11-wireless.mode,802-11-wireless.mtu,802-11-wireless.wake-on-wlan,802-11-wireless-security.key-mgmt,802-11-wireless-security.auth-alg,ipv4.dhcp-hostname-flags,ipv6.method,GENERAL.STATE,label" > data.csv

text=$(head -n 1 data.csv)

for ((i=1; i<=$repeatCount; i++)); do
	output=$(iwconfig wlan0)

	echo "$output" | sed 's/   */\n/g' > output.txt

	output=$(iwlist wlan0 scan)

	echo "$output" | grep -A 27 'Cell 01' | sed 's/   */\n/g' >> output.txt

	output=$(iw dev wlan0 station dump)
	echo "$output" | sed '/^Station/d'  >> output.txt

	output=$(lshw -C network)
	echo "$output" | grep -A 7  "*-network:1" | sed 's/  */\n/g' >> output.txt

	wifi_name=$(iwgetid -r)
	output=$(nmcli connection show "$wifi_name")
	echo "$output" >> output.txt

	output=$(nmcli -f GENERAL,WIFI-PROPERTIES dev show wlan0) 
	echo "$output" >> output.txt

	OLDIFS=$IFS

	IFS=','

	firstValue=true

	for word in $text; do
		if [[ "$word" == "label" ]]; then
			value="$label"
		elif [[ "$word" == "WE" ]]; then
                        value=$(cat /proc/net/wireless | awk 'FNR == 2 {print $17}')
		elif [[ "$word" == "WPA1" ]]; then
                        value=$(nmcli dev wifi | grep "$wifi_name" | grep -o "WPA1")
			if [[ "$value" == "WPA1" ]]; then
				value="yes"
			else
				value="no"
			fi
		elif [[ "$word" == "WPA2" ]]; then
                        value=$(nmcli dev wifi | grep "$wifi_name" | grep -o "WPA2")
                        if [[ "$value" == "WPA2" ]]; then
                                value="yes"
                        else
                                value="no"
                        fi
		elif [[ "$word" == "IP4.ROUTE[1]" ]] || [[ "$word" == "IP4.ROUTE[2]" ]] || [[ "$word" == "IP6.ROUTE[1]" ]] || [[ "$word" == "IP6.ROUTE[2]" ]] || [[ "$word" == "IP6.ROUTE[3]" ]] || [[ "$word" == "IP6.ROUTE[4]" ]]; then
			value=$(grep -F $word output.txt | grep "mt" | sed -n 's/.*= //p')
		elif [[ "$word" == "GENERAL.NAME" ]] || [[ "$word" == "connection.id" ]] || [[ "$word" == "802-11-wireless.ssid" ]] || [[ "$word" == "GENERAL.CONNECTION" ]]; then
			value=$(grep $word output.txt | sed -n 's/.*  //p')
		elif echo "$word" | grep -q "DHCP4.OPTION"; then
			value=$(grep -F $word output.txt | sed -n 's/.*= //p')
		elif echo "$word" | grep -q "DHCP6.OPTION"; then
                        value=$(grep -F $word output.txt | sed -n 's/.*= //p')
		else
			value=$(grep -m 1 -F $word output.txt | grep -oP '[:=]\s*\K[^ ]*')
        	fi
		if [[ "$value" == "--" ]]; then
			value=""
		fi
		if $firstValue; then
                	printf "%s" $value >> data.csv
                	firstValue=false
        	else
                	printf ",%s" $value >> data.csv
		fi
	done

	printf "\n" >> data.csv

	sleep 3

	echo "$i"

	IFS=$OLDIFS
done

rm "output.txt"

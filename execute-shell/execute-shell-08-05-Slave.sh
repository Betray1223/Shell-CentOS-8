#!/usr/bin/bash

######################################## File Description ########################################
# Creation time：2020-05-31
# Project：08
# Task: 05
# Execute example：bash reader-shell-x-x.sh
# Detailed description：
# About：http://linux.book.51xueweb.cn
##################################################################################################

#reback start
yum remove bind-utils -y
cp -f /etc/named.conf.bak1 /etc/named.conf
yum remove bind-utils -y
rm -f /var/named/com-domain-area
rm -f /var/named/10.10.3.area
rm -f /var/named/com-domain-common
rm -f /var/named/10.10.4.common
yum remove bind -y
systemctl start firewalld
setenforce 1
clear
#reback end

#***************reader shell start***************
echo -e "---------------Implementing DNS-Slave---------------\n"
yum install -y bind

#view information
systemctl start named
systemctl status named | head -10

#set the boot
systemctl enable named.service

#view the status of the run
systemctl list-unit-files | grep named.service

#reload named
systemctl reload named

#stop firewalld
systemctl stop firewalld
setenforce 0
echo -e "\n"
read -n1 -p "---------------Please execute Script on Server Master---------------"
echo -e "\n"
echo -e "---------------Configure primary and secondary synchronization and view---------------\n"

#configure primary and secondary synchronization and view on DNS slave
cp -f /etc/named.conf /etc/named.conf.bak1
sed -i '/zone "." IN {/,+3d' /etc/named.conf
sed -i '/named.rfc1912.zones/d' /etc/named.conf
sed -i 's/127.0.0.1/10.10.2.122/g' /etc/named.conf
sed -i 's/localhost/any/g' /etc/named.conf
sed -i "/allow-query/a allow-transfer { none; };\nmasterfile-format text;" /etc/named.conf
echo "> key \"area-key\" {"
echo ">         algorithm hmac-md5;"
echo ">         secret \"areaSecret\";"
echo "> };"
echo "> key \"common-key\" {"
echo ">         algorithm hmac-md5;"
echo ">         secret \"commonSecret\";"
echo "> };"
echo "> EOF"
cat >> /etc/named.conf <<EOF
key "area-key" {
        algorithm hmac-md5;
        secret "areaSecret";
};
key "common-key" {
        algorithm hmac-md5;
        secret "commonSecret";
};
EOF

read -p "Please enter the secret value in the area-key generated by the DNS Master host: " areaSecret
sed -i 's#areaSecret#'''$areaSecret'''#g' /etc/named.conf
read -p "Please enter the secret value in the common-key generated by the DNS Master host: " commonSecret
sed -i 's#commonSecret#'''$commonSecret'''#g' /etc/named.conf
read -p "系统等待"
cat >> /etc/named.conf <<EOF
view "area" {
	match-clients{key area-key; 10.10.2.0/26;};
	server 10.10.2.120 { keys area-key; };
	zone "." IN {
		type hint;
		file "named.ca";
	};
	zone "domain.com" IN {
		type slave;
		file "com-domain-area";
		masters{10.10.2.120;};
	};
	zone "3.10.10.in-addr.arpa" IN {
		type slave;
		file "10.10.3.area";
		masters{10.10.2.120;};
	};
};
view "common" {
	match-clients { key common-key; any;};
	server 10.10.2.120 { keys common-key; };
	zone "." IN {
		type hint;
		file "named.ca";
	};
	zone "domain.com" IN {
		type slave;
		file "com-domain-common";
		masters{10.10.2.120;};
	};
	zone "4.10.10.in-addr.arpa" IN {
		type slave;
		file "10.10.4.common";
		masters{10.10.2.120;};
	};
};
EOF

#check the correctness of bind master configuration file
named-checkconf /etc/named.conf
systemctl reload named
ls /var/named
cat /var/named/com-domain-area
cat /var/named/com-domain-common
cat /var/named/10.10.3.area
cat /var/named/10.10.4.common
cat /var/named/data/named.run | head -n 60
echo -e "\n"
read -n1 -p "---------------Please execute Script on Server Master---------------"
echo -e "\n"
echo -e "---------------Testing domain name resolution service on DNS slave---------------\n"
yum install -y bind-utils
dig www.domain.com @10.10.2.120
dig www.domain.com @10.10.2.122

#***************reader shell end*****************
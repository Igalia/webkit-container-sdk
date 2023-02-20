#!/usr/bin/bash
chown -R proxy.proxy /data
chown proxy.proxy /dev/stdout

source /usr/share/squid-deb-proxy/init-common.sh
pre_start
post_start
exec /usr/sbin/squid -N -f /etc/squid-deb-proxy/squid-deb-proxy.conf

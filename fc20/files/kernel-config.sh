#!/bin/sh
# This file is maintained centrally, do not edit here.
# 
# Begin-Doc
# Name: rc.000.kernel-config
# Type: script
# Description: runtime kernel configuration options
# Comment: Edit the templates on falcon and the per-host
# config in the hostinfo database tables.
# End-Doc
#




# Per-host preconfig options.
# Proc setting utility for linux
# Echoes what is being set to the logs
setproc()
{
	if [ -e $1 ]; then
		echo "setproc $1 from '"`cat $1`"' to '$2'"
	else
		echo "setproc skipping invalid $1"
	fi
	echo $2 > $1
}

#
# Make sure iptables is loaded
#
iptables -L -v
ip6tables -L -v

#
# Try to auto-reboot
#
setproc /proc/sys/kernel/sysrq 1
setproc /proc/sys/kernel/panic 30

# Larger local port range
setproc /proc/sys/net/ipv4/ip_local_port_range "1024 65000"

# Reduce default tcp fin wait time
setproc /proc/sys/net/ipv4/tcp_fin_timeout 30

# Allow higher rate of incoming connections
setproc /proc/sys/net/core/somaxconn 3000
setproc /proc/sys/net/core/netdev_max_backlog 3000

#
# TCP tuning
#
setproc /proc/sys/net/ipv4/tcp_rmem "4096 5000000 16777216"
setproc /proc/sys/net/ipv4/tcp_wmem "4096 65536 16777216"

# Tune keepalives
# 10 minutes
setproc /proc/sys/net/ipv4/tcp_keepalive_time 600
setproc /proc/sys/net/ipv4/tcp_keepalive_intvl 15
setproc /proc/sys/net/ipv4/tcp_keepalive_probes 5

# Max number of pending socket connections
setproc /proc/sys/net/ipv4/tcp_max_syn_backlog 16384

#
# Network I/O buffer sizes
#
setproc /proc/sys/net/core/wmem_default 262144
setproc /proc/sys/net/core/wmem_max 8388608
setproc /proc/sys/net/core/rmem_default 262144
setproc /proc/sys/net/core/rmem_max 8388608

# Max shared memory size
# I don't see any reason for this on non-oracle-server machines
#setproc /proc/sys/kernel/shmmax 2147483648

# Semaphores
# No reason for it on non-oracle
#setproc /proc/sys/kernel/sem "250 32000 100 128"

# Defaults to 60, lower number is more likely to free page cache than to write to swap
# let's leave alone for now
#setproc /proc/sys/vm/swappiness 20

#  oracle claims to want 6.8 million, that is utterly insane
if [ `cat /proc/sys/fs/file-max` -lt 256000 ]; then
    setproc /proc/sys/fs/file-max 256000
fi

#
# Increase default scsi timeouts for typical san use
#
for sd in `ls /sys/class/scsi_device`; do
   setproc /sys/class/scsi_device/$sd/device/timeout 120
done


# Per-host config, configured in hostinfo.

#!/bin/sh
#
#
# cd /tmp; rm -f post.sh; wget http://ks.spirenteng.com/fedora/20/post.sh; chmod 755 post.sh; ./post.sh
#

#
# just in case
alias cp=cp
alias mv=mv
alias rm=rm
unalias cp
unalias rm
unalias mv

# clean up awful root aliases
ed /root/.bashrc <<EOF
g/alias/d
.
w
q
EOF

# Check if we're on a fc17 install
grep "release 20" /etc/fedora-release >/dev/null
if [ $? != 0 ]; then
  echo "ERROR: Not on Fedora-20 install. Exiting."
  exit 1
fi

# Create local
mkdir -p /local


#
# Set up SSH keys
#
umask 077
mkdir -p /root/.ssh

cat <<EOF >> /root/.ssh/authorized_keys
ssh-dss AAAAB3NzaC1kc3MAAACBAJnUXzaH/UK6/AfAFKTBJK+tLlvwPwyuhBtDi5Z1Klj5gEh3lz8WvOthMunm/eJyEaekQ88c4OFbq9eoGgmO234Y4revTTuala2jb/2jTjYoRfM7brdaBaKpsLWx2i2lIzkg2+yZzGx+0uhWSZ5ZaRDxshQtVqCoFN+uE6LmXgC3AAAAFQCAS0ONVw3bRAHlIT2v3jcpSmclaQAAAIA6NFkjBMk7jn+Lkovk1wtRs4UupGlJGLJsnnm68HTYvP9v/4j3fvV0Wyh/kJiN/lZbF/7xTTx65+JI0Ar+sRnkBgzMJwl/ahWMAa6tjO0qeSchWDX3GO1vlYi4BkGfZfBDtzq0O8L5Q09oAwx3flgqJmEiS11K24MixyOVqF4v5wAAAIAInVjAvKdDykMEzXDvJFXwOUlaIaCP7HhzcYt2IK8lRLckOsv3kq+8Ob7Rhw1IulFxORHwWs8jEsJJGCpJgImrMRkqWixOgPy6VwVaWjnkEZrLPXuIsYbLmATCodfdA38XF35iTjcGzow1+aNliryxvF+LigjqEWQD0tnGtWqQKQ== nneul@neulinger.org

EOF
cat /root/.ssh/authorized_keys \
	| sort \
	| uniq \
	| grep -v -i abovill \
	> /root/.ssh/new_auth_keys
mv /root/.ssh/new_auth_keys /root/.ssh/authorized_keys

yum --nogpgcheck -y install ed

#
# Turn off peerdns in network configs
#
if [ -e /etc/sysconfig/network-scripts/ifcfg-eth0 ]; then
ed /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOM
g/DNS/d
a
PEERDNS=no
.
w
q
EOM
fi

#
# Cleanup old kernels
#
perl -pi -e "s/installonly_limit=3/installonly_limit=2/go" /etc/yum.conf
package-cleanup -y --oldkernels --count=2

#
# Install a few other custom RPMs
#
yum -y install https://github.com/unixtools/authsrv/releases/download/v3.1.0/authsrv-3.1.0-1.fc20.x86_64.rpm
yum -y install https://github.com/unixtools/rclocal/releases/download/v2.0.8/rclocal-2.0.8-1.noarch.rpm
yum -y install https://github.com/unixtools/triggerd/releases/download/v1.5/triggerd-1.5-1.fc20.x86_64.rpm

mkdir -p /local
cd /local/
git clone https://github.com/unixtools/perllib

cat >/etc/yum.repos.d/google-chrome.repo <<EOF
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=0
skip_if_unavailable=true
EOF

#
# Add other config files
#
cp /root/install/fc20/files/vimrc /etc/vimrc
cp /root/install/fc20/files/root-bashrc /root/.bashrc
cp /root/install/fc20/files/perltidyrc /etc/perltidyrc
cp /root/install/fc20/files/rsyslog.conf /etc/rsyslog.conf

mkdir -p /home/local
service rsyslog restart

mkdir -p /home/local/adm/rc-start
cp /root/install/fc20/files/kernel-config.sh /home/local/adm/rc-start/rc.000.kernel-config
chmod 755 /home/local/adm/rc-start/rc.000.kernel-config
/home/local/adm/rc-start/rc.000.kernel-config

#
# Install rpmfusion repos
#
yum -y localinstall --nogpgcheck http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
	http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

rpmkeys --verbose --import /etc/pki/rpm-gpg/RPM-GPG-KEY-*

#
# Generate and run the yum script
#
echo "upgrade" > /tmp/yum-cmds.txt
cat /root/install/fc20/files/added-rpms | awk '{ print "install " $1 }' >> /tmp/yum-cmds.txt
echo "install google-chrome-stable" >> /tmp/yum-cmds.txt
echo "install yum-updatesd" >> /tmp/yum-cmds.txt
echo "run" >> /tmp/yum-cmds.txt
echo "exit" >> /tmp/yum-cmds.txt

yum -y --nogpgcheck shell </tmp/yum-cmds.txt

# Enable yum-cron
# Leave off for now
#perl -pi -e "s/do_update = no/do_update = yes/go" /etc/yum/yum-updatesd.conf
#perl -pi -e "s/emit_via = dbus/emit_via = syslog/go" /etc/yum/yum-updatesd.conf
#chkconfig yum-updatesd on
#service yum-updatesd restart

# Make wireshark usable by all users
chmod 4755 /usr/sbin/dumpcap

chkconfig chronyd off
chkconfig ntpd on
chkconfig ntpdate on
service ntpd stop
service ntpdate restart
service ntpd restart

chkconfig sendmail on
service sendmail restart

# Enable log rotation
cat > /etc/logrotate.d/home-local-messages-debug <<EOF
/home/local/messages.debug
{
    sharedscripts
    postrotate
    /bin/kill -HUP \`cat /var/run/syslogd.pid 2> /dev/null\` 2> /dev/null || true
    endscript
}
EOF

# Enable log rotation
cat > /etc/logrotate.d/local-apache <<EOF
/local/apache-root*/logs/access_log
/local/apache-root*/logs/error_log
{
    missingok
    compress
    delaycompress
    daily
    rotate 14
    sharedscripts
    postrotate
    /usr/bin/pkill -USR1 httpd 2> /dev/null 2> /dev/null || true
    endscript
}
EOF

# Missing in default since I use /home/local/messages.debug
touch /var/log/cron

# Force timezone selection if not already set to UTC
rm -f /etc/localtime
ln -s ../usr/share/zoneinfo/Etc/UTC /etc/localtime

# Default to new git push behavior
git config --global push.default simple



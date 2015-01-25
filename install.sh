#!/bin/sh

# subfunctions
usage()
{
cat << EOF
Usage:
  $(basename ${0}) [-u username] [-ivh]

Options:
  -i		install
  -u username   add sudoer
  -v		install virtualbox guest additions
  -h		help

EOF
}

update_ports()
{
	cd /usr/ports
	portsnap fetch
	portsnap extract
	portsnap update
	make fetchindex
}

install_pkg()
{
	# install pkg
	cd /usr/ports/ports-mgmt/pkg
	make install clean
	# install
	cd /usr/ports
	echo 'y' | pkg install sudo
	echo 'y' | pkg install zsh
	echo 'y' | pkg install vim
	echo 'y' | pkg install xorg
}

set_configure()
{
	cd ~/
	echo hald_enable="YES" >> /etc/rc.conf
	echo dbus_enable="YES" >> /etc/rc.conf
	Xorg -configure
	cp xorg.conf.new /etc/X11/xorg.conf
}

set_virtualbox()
{
	cd ~/
	echo 'y' | pkg install virtualbox-ose-additions
	echo 'vboxguest_enable="YES"' >> /etc/rc.conf
	echo 'vboxservice_enable="YES"' >> /etc/rc.conf
cat << EOF > $TEMPFILE
\$area = 0;
while (<>) {
	if (\$area == 0) {
		if (/^Section\s+"InputDevice"/) {
			\$area = 1;
		}
		if (/(^\s+Driver\s+)"vesa"/) {
			print "\$1\"vboxvideo\"\n"
		} else {
			print;
		}
	} elsif (\$area == 1) {
		if (/Identifier\s+"Mouse0"/) {
			\$area = 2;
		} else {
			\$area = 0;
		}
		print;
	} elsif (\$area == 2) {
		if (/^\s+Driver\s/) {
			print "\tDriver\t\"vboxmouse\"\n";
		}
		if (/EndSection/) {
			print;
			\$area = 0;
		}
	}
}
EOF
	cat /etc/X11/xorg.conf | perl $TEMPFILE > $TEMPFILE2
	cp $TEMPFILE2 /etc/X11/xorg.conf
	chmod 644 /etc/X11/xorg.conf
}

# getopt
args=`getopt hiu:v $*`
if [ $? -ne 0 ]; then
	usage
	exit 2
fi
set -- $args
while true; do
	case "$1" in
	-i)
		installflag="${1#-}$installflag"
		shift
		;;
	-h)
		usage
		exit 0
		;;
	-v)
		vboxflag="${1#-}$vboxflag"
		shift	
		;;
	-u)
		username="$2"
		shift
		shift
		;;
	--)
		shift
		break
		;;
	esac
done

# temp file
trap 'rm -f "$TEMPFILE"' EXIT
TEMPFILE=`mktemp /tmp/$0.XXXXXX`
trap 'rm -f "$TEMPFILE2"' EXIT
TEMPFILE2=`mktemp /tmp/$0.XXXXXX`

# install
if [ ! -z $installflag ]; then
	update_ports
	install_pkg
	set_configure
fi

# set sudoer
if [ ! -z ${username} ]; then
	echo "${username} ALL=(ALL) ALL" > /usr/local/etc/sudoers.d/${username}
	chmod 0440 /usr/local/etc/sudoers.d/${username}
fi

# install virtualbox guest additions
if [ ! -z $vboxflag ]; then
	set_virtualbox
fi



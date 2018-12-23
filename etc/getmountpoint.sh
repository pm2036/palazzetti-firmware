MNT=""

COUNT=0
while [ $COUNT -le 3 ]; do
	# wait if device is mounted
	#logger -t DEBUG logger try to find mount point..
	MNT=`cat /proc/mounts | grep "/mnt/sd" | awk '{print $2}'`
	if [ -n "$MNT" ]; then
		break
	fi
	COUNT=`expr $COUNT + 1`
	/etc/init.d/fstab restart
	sleep 2
done
if [ -z "$MNT" ]; then
	#logger -t DEBUG logger terminated!
	exit
fi

echo $MNT

#!/bin/sh
LOOP=1

if [ -z "$1" ]; then
	FILECSV=/www/sequencer.csv
else
	PAR1=`echo $1 | awk '{print toupper($0)}'`
	if [ "$PAR1" == "TESTSEQ" ]; then
		FILECSV=/www/testseq.csv
	else
		exit
	fi

fi

while [ $LOOP -eq 1 ]
do
	LOOP=0


	[ ! -f $FILECSV ] && { echo "$FILECSV file not found"; exit 99; }
	while read line
	do
		if [ "$(echo "$line" | cut -c0-1)" == "#" ]; then
			continue
		fi

		if [ -z "$line" ]; then
			continue
		fi

		f1=`echo $line | cut -d';' -f1 | awk '{print toupper($0)}'`
		f2=`echo $line | cut -d';' -f2 | awk '{print toupper($0)}'`

		echo "f1: $f1, f2: $f2"

		if [ "$f1" == "LOOP" ]; then
			if [ "$f2" == "1" ]; then
				LOOP=1
			fi
		elif [ "$f1" == "STARTLOGGER" ]; then
			if [ "$PAR1" == "TESTSEQ" ]; then
				php-fcgi -q /www/syscmd.php "cmd=startlogger&fileprefix=testseq" &
			else
				php-fcgi -q /www/syscmd.php cmd=startlogger &
			fi
		elif [ "$f1" == "STOPLOGGER" ]; then
			php-fcgi -q /www/syscmd.php cmd=stoplogger &
		else
			TS=`date +%Y%m%d%H%M%S`

			echo "$TS;$f1;`expr $f2 \* 60`" > /tmp/seqcurrent
			# find all commands
			i=1
			cmd=`echo $f1 | cut -d',' -s -f$i`
			if [ ${#cmd} -eq 0 ]; then
				# just one commands
				sendmsg "$f1"
			else

				while [ ${#cmd} -gt 0 ]
				do
					echo "sendmsg $cmd"
					sendmsg "$cmd"
					sleep 1

					i=$(( i+1 ))
					cmd=`echo $f1 | cut -d',' -f$i`
				done
			fi

			i=`expr $f2 \* 60`
			while [ $i -gt 0 ]
			do
				echo "var i=$i"
				i=`expr $i - 5`
				echo "$TS;$f1;$i" > /tmp/seqcurrent
				sleep 5
			done

		fi

	done < $FILECSV

done

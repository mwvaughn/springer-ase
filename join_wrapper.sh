#!/bin/bash

EMPTY_STRING=""
FORMAT=""
DELIMITER="tab"
IGNORE_CASE=""
INPUT1=
INPUT2=
COLUMN1=
COLUMN2=
OUTPUT=""

while getopts ":j:f:e:d:1:a:2:b:o:ih" opt; do
case $opt in
	j)
		JOINTYPE=$OPTARG
		echo "Join $JOINTYPE"
		;;
	f)
		FORMAT=$OPTARG
		;;
	e)
		EMPTY_STRING=$OPTARG
		;;
	d)
		DELIMITER=$OPTARG
		;;
	i)
		IGNORE_CASE=$opt
		;;
	1)
		INPUT1=$OPTARG
		;;
	2)
		INPUT2=$OPTARG
		;;
	a)
		COLUMN1=$OPTARG
		;;
	b)
		COLUMN2=$OPTARG
		;;
	o)
		OUTPUT=$OPTARG
		;;
	h)
		echo "Usage goes here"
		exit
		;;
esac
done

# This is added as a workaround until DiscoveryEnvironment supports key:alias pairs
# for value select parameters
case $JOINTYPE in
	Both)
		JOINPARAM=""
		;;
	First_Not_Second)
		JOINPARAM="-v 1"
		;;
	Second_Not_First)
		JOINPARAM="-v 2"
		;;
	Both_Plus_Unpaired_From_First)
		JOINPARAM="-a 1"
		;;
	Both_Plus_Unpaired_From_Second)
		JOINPARAM="-a 2"
		;;
	All)
		JOINPARAM="-a 1 -a 2"
		;;
esac

if [ "$OUTPUT" == "" ]; then	
	echo "For some reason no output file was specified. That's pretty much a fail.\n" >&2
	exit 1;
fi

#This a TAB hack for galaxy (which can't transfer a "\t" as a parameter)
[ "$DELIMITER" == "tab" ] && DELIMITER="	"
[ "$DELIMITER" == "comma" ] && DELIMITER=","
[ "$DELIMITER" == "space" ] && DELIMITER=" "

#Remove spaces from the output format (if the user entered any)
OUTPUT_FORMAT=${OUTPUT_FORMAT// /}
[ "$OUTPUT_FORMAT" != "" ] && OUTPUT_FORMAT="-o $OUTPUT_FORMAT"

echo join -t "$DELIMITER" -e "$EMPTY_STRING" $IGNORE_CASE $JOINPARAM -1 "$COLUMN1" -2 "$COLUMN2" "$INPUT1" "$INPUT2" 

join -t "$DELIMITER" -e "$EMPTY_STRING" $JOINPARAM -1 "$COLUMN1" -2 "$COLUMN2" "$INPUT1" "$INPUT2" > "$OUTPUT" || exit 1

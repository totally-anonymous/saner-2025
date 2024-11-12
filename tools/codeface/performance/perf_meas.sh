#! /bin/bash
# Simple script to measure codeface ressource usage with collectl
# Copyright Siemens AG 2013, Wolfgang Mauerer
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

if [ $# -ne 5 ]; then
    echo "Usage: $0 project cores outdir resdir repodir";
    echo "(resdir contains codeface results,";
    echo " outdir contains measured performance data)"

    exit -1;
fi

PROJECT=$1
CORES=$2
OUTDIR=$3
RESDIR=$4
REPODIR=$5

mkdir -p ${OUTDIR}

echo "Analysing $PROJECT with $CORES cores (results are in ${OUTDIR})"

codeface -j${CORES} run --recreate -c codeface.conf -p conf/${PROJECT}.conf \
         ${RESDIR} ${REPODIR} &>/dev/null &

CODEFACE=$!

sudo collectl -i1:1 -sZ --procfilt P$! --procopts mct -P --sep 9 \
              -f ${OUTDIR}/${PROJECT}_${CORES} &>/dev/null &
COLLECTL=$!

echo -n "Waiting for codeface (PID ${CODEFACE}) to finish..."
wait ${CODEFACE}
echo "done."
echo "Stopping data collection from PID ${COLLECTL}."
sudo kill ${COLLECTL}

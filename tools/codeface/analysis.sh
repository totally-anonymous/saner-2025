#! /bin/sh

project=$1
cores=$2

exec 3>&1 1>>>(tee "/home/saner/tools/codeface/log/${project}.log") 2>&1

echo "Start:" `date -u`
start=`date +%s`

printf 'Analysing %s with Codeface using %d cores...\n' $project $cores

# Start codeface analysis
sudo mkdir -p /home/saner/data/codeface
echo "`codeface -j $cores run \
	 -c /home/saner/tools/codeface/codeface.conf \
	 -p /home/saner/tools/codeface/conf/${project}.conf \
	 /home/saner/data/codeface /home/saner/data/git-repos`"

echo "End:" `date -u`
end=`date +%s`
d=$(($end-$start))
printf 'Time elapsed: %dd:%dh:%dm:%ds (%ds)\n' $((d/86400)) \
        $((d%86400/3600)) $((d%3600/60)) $((d%60)) $d


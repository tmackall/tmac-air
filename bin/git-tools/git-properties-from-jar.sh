#!/bin/bash

if [[ $# -ne 1 ]]; then
   echo -e "\n\nusage $0 <hdfs jar file>"
   echo -e "$0 hdfs:///apps/nudp/spark-event-ingestion.jar\n"
   exit 0
fi

#
# hdfs jar file to break open
JAR=$1
echo "$JAR"

#
# filename - remove it from the path
BNAME=$(basename $JAR)

PROP_FILE="git-spark-job.properties"
rm ${PROP_FILE} &> /dev/null
TMP_FILE="${BNAME}" 
echo "$TMP_FILE"
rm ${TMP_FILE} &> /dev/null

#
# jar file - copy from hdfs to the local dir
hdfs dfs -get ${JAR} ${TMP_FILE}
#
# git properties - extract from the JAR
cmd="jar xf ${TMP_FILE} ${PROP_FILE}"
echo "$cmd"
eval $cmd
#
# commit id - get it from the file
grep git.commit.id= ${PROP_FILE} | sed 's/.*=//'
exit 0

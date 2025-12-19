#!/bin/bash
cmd="rsync -avz --exclude-from=exclude-list.txt home2:/home/tmackall/ ~/hom2-bck/"
cmd="rsync -avz --exclude-from=exclude-list.txt home2:/mnt/disk1/ ~/hom2-bck/disk1/"
echo "$cmd"
eval $cmd
exit 0

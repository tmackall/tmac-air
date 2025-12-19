#!/bin/bash


cmd="rsync -avz /Users/tom.mackall/Pictures/ niwot:/home/tmackall/pictures/"
echo "$cmd"
eval $cmd
cmd="rsync -avz /Users/tom.mackall/taxes/ niwot:/mnt/usb-ext-hd1/taxes/"
echo "$cmd"
eval $cmd

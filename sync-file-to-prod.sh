#!/usr/bin/fish

set -l host $argv[1]
set -l dir (dirname $argv[2])
set -l file (basename $argv[2])

set -l project_dir_on_host /var/www/ryte

ssh $host "mkdir -p /tmp/$dir"
and scp $dir/$file $host:/tmp/$dir/$file
and ssh $host "sudo cp /tmp/$dir/$file $project_dir_on_host/$dir/$file"

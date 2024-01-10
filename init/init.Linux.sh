#!/bin/bash


###########################################################
# This scripts aims to initialize the running environment #
# for repository <reSync>, including:                     #
#    ● gather correponding binary to target dir           #
#    ● generate init script                               #
#    ● generate modulefile                                #
# --------------------------------------------------------#
# by Roadelse                                             #
#                                                         #
# 2024-01-09    created                                   #
###########################################################


myDir=$(cd $(dirname "${BASH_SOURCE[0]}") && readlink -f .)

# <L1> resolve argument
# ...
# ...
# ...
binary_dir=${PWD}/bin
load_script=${PWD}/load.reSync.sh
modulefile=${PWD}/reSync
profile=
while getopts "b:s:m:p:" arg; do
    case $arg in
    b)
        binary_dir=$OPTARG;;
    s)
        load_script=$OPTARG;;
    m)
        modulefile=$OPTARG;;
    p)
        profile=$OPTARG;;
    esac
done



# <L1> handle jsync
mkdir -p $binary_dir && cd $_
ln -sf `realpath $myDir/../jsync/jsync.sh` jsync

# <L1> handle robs
ln -sf `realpath $myDir/../robsys/robs.sh` robs

# <L1> handle load_script & modulefile
cat << EOF > $load_script
#!/bin/bash

export PATH=${binary_dir}:\$PATH

EOF

cat << EOF > $modulefile
#%Module 1.0

prepend-path PATH ${binary_dir}

EOF
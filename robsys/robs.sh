#!/bin/bash

# This script aims to toggle working directories among OneDrive/BaiduSync/local-recRoot
# by rdee in wxsc-7f @2023-05-10 14:34:59


# >>>>>>>>>>>>>>>>> 1. validate system settings and current directory, prepare paths
# ======= check environment variables
if [[ -z ${OneDrive} || -z ${BaiduSync} || -z ${recRoot} ]]; then
    echo "env:OneDrive, env:BaiduSync and env:recRoot are all necessary!"
    return 1 # exit 1
fi

# ======= check current directory
currDir=${PWD}
if [[ ${currDir/$OneDrive//} != ${currDir} ]]; then
    status=OneDrive
elif [[ ${currDir/$BaiduSync//} != ${currDir} ]]; then
    status=BaiduSync
elif [[ ${currDir/$recRoot//} != ${currDir} ]]; then
    status=recRoot
else
    echo "neither of OneDrive/BaiduSync/recRoot match the current directory!"
    return 2 # exit 2
fi


# ======= prepare paths
cDir=${!status}
oDir=${currDir/$cDir/$OneDrive}
bDir=${currDir/$cDir/$BaiduSync}
rDir=${currDir/$cDir/$recRoot}



# >>>>>>>>>>>>>>>>> 2. resolve options and confirm actions
# ======= basic information
oDirE='×' ; bDirE='×' ; rDirE='×'  # check dir existance
if [[ -e $oDir ]]; then oDirE='√'; fi
if [[ -e $bDir ]]; then bDirE='√'; fi
if [[ -e $rDir ]]; then rDirE='√'; fi

oDirC=' ' ; bDirC=' ' ; rDirC=' '  # check current directory
if [[ $status == OneDrive ]]; then oDirC='*'; fi
if [[ $status == BaiduSync ]]; then bDirC='*'; fi
if [[ $status == recRoot ]]; then rDirC='*'; fi

# ======= show information
if [[ $# == 0 ]]; then
    echo "OneDrive  (${oDirE})${oDirC} : $oDir"
    echo "BaiduSync (${bDirE})${bDirC} : $bDir"
    echo "recRoot   (${rDirE})${rDirC} : $rDir"

    return 0 # exit 0
fi

# ======= resolve options
create_if_nE=0
while getopts "c" arg
do
    case $arg in 
        c)
            create_if_nE=1
            shift;;
        *)
            echo Error
            return 3 # exit 3
    esac
done     

# echo $create_if_nE
# echo $@
if [[ $# != 1 ]]; then
    echo "unexpected argument numbers"
    return 4 # exit 4
fi

target=$1
if [[ $target != o && $target != b && $target != r ]]; then
    echo "unknown target : $target"
    return 5 # exit 5
fi

tDirName=${target}Dir
tDir=${!tDirName}

if [[ ! -e $tDir ]]; then
    if [[ $create_if_nE == 1 ]]; then
        mkdir -p $tDir
        cd $tDir
        return 0 # exit 0
    else
        echo "$tDir doesn't exist! add '-c' maybe"
        return 6 # exit 6
    fi
fi

cd $tDir
pwd






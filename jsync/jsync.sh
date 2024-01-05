#!/bin/bash

# This script aims to simplify rsync command based on project-level pre-defined paths among multiple machines

# -m : mode, get/put, put2 (automatically create all missing directories)
# -t : target in .jsyncrc

# 2022-12-21    init
# 2024-01-05    optimized & add support for updating default target in .jsyncrc 



# <L1> static parameters
configFile=.jsyncrc


# <L1> search configFile from PWD to /
tarDir=${PWD}
rPath=""
while [[ $tarDir != '/' ]]
do
    if [[ -e $tarDir/$configFile ]]; then
        break
    fi
    rPath=`basename $tarDir`"/$rPath"
    tarDir=`dirname $tarDir`
done

if [[ ! -e $tarDir/$configFile ]]; then
    echo "cannot find $configFile in the current and all parent directories! Error"
    exit 101
fi

echo "configFile : $tarDir/$configFile"

# <L1> show configFile content if no argument specified
if [[ -z "$@" ]]; then
    cat $tarDir/$configFile
    exit 0
fi


# <L1> resolve CLI arguments using getopts
mode=put
target=default
unittest=0
while getopts "m:t:u" arg
do
    case $arg in 
        m)
            mode=$OPTARG;;
        t)
            target=$OPTARG;;
        u)
            unittest=1;;
    esac
done
shift ((OPTIND-1))


if [[ $unittest == "0" ]]; then

# <L1> Confirm mode & target
addr=
while read line
do
    eList=($line)
    # <L2> if no target specified
    if [[ $target == default ]]; then
        echo ${line}
        addr=${eList[1]}
        break
    fi
    # <L2> find target and move it top top
    if [[ "${eList[0]}" == "$target" ]]; then
        addr=${eList[1]}
        awk 'NR==1{print s} $0!~s' s="$line" > $tarDir/$configFile
        break
    fi
done < $tarDir/$configFile

# <L2> cannot find target
if [ -z "$addr" ]; then
    echo "cannot find target <$target>"
    exit 102
fi

# <L1> call rsync based on mode & target
# <L2> handle target files 
targetFiles="$@"
if [[ $targetFiles == "" ]]; then
    targetFiles="*"
fi

# <L2> put mode
if [[ "$mode" =~ put.* ]]; then
    echo "entering <put> mode"
    rsync -avPL $targetFiles $addr/$rPath

# <L2> put2 mode
elif [[ "$mode" == "put2" ]]; then
    echo "entering <put2> mode"
    mach_addr=(${addr//:/ })
    mach=${mach_addr[0]}
    ssh $mach "mkdir -p ${mach_addr[1]}/$rPath"
    rsync -avPL $targetFiles $addr/$rPath

# <L2> get mode
elif [[ "$mode" == 'get' ]]; then
    for npat in "$@"; do  #>- npat: name pattern
        echo "rsync -avPL $addr/$rPath/$targetFiles ."
        # echo $addr
        # echo $rPath
        # echo $targetFiles
        rsync -avPL $addr/$rPath/$npat .
    done
else
    echo "Error! Unknown mode: $mode"
    exit 103
fi


else
    # <L1> unittest
    mkdir jsync_utest && cd $_
    mkdir -p dir1/a dir1/b dir2/c dir2/d
    touch dir1/x dir1/a/y dir2/z dir2/d/m

    cd dir1
    cat > .jsyncrc << EOF
plh1 ababa:/home
test ${PWD}/dir2
EOF
    jsync -m get -t test d
    if [[ -e d/e ]]; then
        echo "mode:get test passed"
    else
        echo "mode:get test failed"
        exit 200
    fi
    if [[ `head -n 1 .jsyncrc` =~ test.* ]]
fi
#!/bin/bash

# This script aims to simplify rsync command based on project-level pre-defined paths among multiple hosts

# -m : mode, get/put, put2 (automatically create all missing directories)
# -t : target in .jsyncrc

# 2022-12-21    init
# 2024-01-06    rebuild. Support multiple targets, auto-move last-used target to top, local transfer, relative transfer. Skeleton comments are reformatted



###########################################################
# Prepare
###########################################################
# >>>>>>>>>>>>> pre-settings & static params <<<<<<<<<<<<<<
set -e

configFile=.jsyncrc
exe=$0


# >>>>>>>>>>>> search configFile from PWD to / <<<<<<<<<<<<
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

# >>>>>>>>>>>>>>>> show configFile content <<<<<<<<<<<<<<<<
# if no argument specified and $configFile existed
if [[ -z "$@" ]]; then
    if [[  -e $tarDir/$configFile ]]; then
        echo "configFile : $tarDir/$configFile"
        cat $tarDir/$configFile
    else
        echo "Not within a jsync project path, exit"
    fi
    exit 0
fi


# >>>>>>>>>>>> resolve CLI arguments and check <<<<<<<<<<<<
# ================== default arg-relative variables
mode=put
target=default
unittest=0
echo_only=0
# ================== getopts resolution
while getopts "m:t:ue" arg
do
    case $arg in 
        m)
            mode=$OPTARG;;
        t)
            target=$OPTARG;;
        u)
            unittest=1;;
        e)
            echo_only=1;;
    esac
done
# ================== post-processing
if [[ $unittest == 1 && $OPTIND -gt 2 ]]; then
    echo "Error! -u can only be used alone"

    exit 200
fi
# ~~~~~~~~~~ adjust arg index
shift $((OPTIND-1))



###########################################################
# Core logic: 
###########################################################
if [[ $unittest == "0" ]]; then #>- not in unittest mode
# >>>>>>>>>>>>>>>>> Confirm mode & target <<<<<<<<<<<<<<<<<
addr=
while read line
do
    eList=($line)
    # ================== use 1st target if not specified
    if [[ $target == default ]]; then
        echo "target detected: ${line}"
        addr=${eList[1]}
        break
    fi

    # ================== find target and move it to top
    if [[ "${eList[0]}" == "$target" ]]; then
        addr=${eList[1]}
        awk 'NR==1{print s} $0!~s' s="$line" $tarDir/$configFile > $tarDir/$configFile.2  #>- move target line to top
        mv -f $tarDir/$configFile.2 $tarDir/$configFile
        break
    fi
done < $tarDir/$configFile

# ================== cannot find target
if [ -z "$addr" ]; then
    echo "cannot find target <$target>"
    exit 102
fi


# >>>>>>>>>>> call rsync based on mode & target <<<<<<<<<<<
# ================== handle target files 
targetFiles="$@"
if [[ $targetFiles == "" ]]; then
    targetFiles="*"
fi

targetPaths=()
for a in "$targetFiles"; do
    # echo "realpath \"$a\" --relative-to \"$tarDir\""
    targetPaths+=(`realpath -m "$a" --relative-to "$tarDir"`)
done

# ================== put mode
if [[ "$mode" =~ put.* ]]; then
    echo "entering <put> mode"
    
    echo "exec: rsync -avPLR \"${targetPaths[@]}\" $addr"
    # ~~~~~~~~~~ do not call rsync if echo_only == 1
    if [[ $echo_only == 0 ]]; then
        cd $tarDir #>- Must do the rsync in project directory for relative rsync
        rsync -avPLR "${targetPaths[@]}" $addr
    fi

# ================== get mode
elif [[ "$mode" == 'get' ]]; then
    echo "entering <get> mode"

    # ~~~~~~~~~~ complete the remote address
    # the "/./" is NECESSARY for relative rsync!
    for i in ${!targetPaths[@]}; do
        targetPaths[$i]=${addr}/./${targetPaths[$i]}
    done
    
    echo "exec: rsync -avPLR \"$targetPaths\" $tarDir"
    # ~~~~~~~~~~ do not call rsync if echo_only == 1
    if [[ $echo_only == 0 ]]; then
        rsync -avPLR "$targetPaths" $tarDir
    fi
else
    echo "Error! Unknown mode: $mode"
    exit 103
fi



# >>>>>>>>>>>>>>>>>>>>>>> unittest <<<<<<<<<<<<<<<<<<<<<<<<
else
    # ================== local test
    # ~~~~~~~~~~ prepare files & dirs
    mkdir jsync_utest && cd $_
    mkdir -p dir1/a dir1/b dir2/c dir2/d
    touch dir1/x dir1/a/y dir2/z dir2/d/m

    cd dir1

    # ~~~~~~~~~~ write .jsyncrc
    cat > .jsyncrc << EOF
plh1 ababa:/home
test1 ${PWD/%dir1/dir2}
EOF
    # ~~~~~~~~~~ call jsync & check results
    $exe -m get -t test1 d/m
    if [[ -e d/m ]]; then
        echo -e "\033[32m mode:get test passed \033[0m"
    else
        echo -e "\033[31m mode:get test failed \033[0m"
        exit 200
    fi

    # ~~~~~~~~~~ call jsync & check results
    if [[ `head -n 1 .jsyncrc` =~ test1.* ]]; then
        echo -e "\033[32m move target test passed \033[0m"
    else
        echo -e "\033[31m move target test failed \033[0m"
        exit 200
    fi

    # ~~~~~~~~~~ call jsync & check results
    $exe a/y x
    if [[ -e ../dir2/x && -e ../dir2/a/y ]]; then
        echo -e "\033[32m mode:put test passed \033[0m"
    else
        echo -e "\033[31m mode:put test failed \033[0m"
        eixt 200
    fi
   
    # ~~~~~~~~~~ call jsync & check results
    rm -rf ../dir2/*
    $exe *
    if [[ -e ../dir2/x && -e ../dir2/a/y && -e ../dir2/d/m ]]; then
        echo -e "\033[32m mode:put with expaned wildcard test passed \033[0m"
    else
        echo -e "\033[31m mode:put with expaned wildcard test failed \033[0m"
        eixt 200
    fi

    # ~~~~~~~~~~ call jsync & check results
    rm -rf ../dir2/*
    $exe \*
    if [[ -e ../dir2/x && -e ../dir2/a/y && -e ../dir2/d/m ]]; then
        echo -e "\033[32m mode:put with non-expaned wildcard test passed \033[0m"
    else
        echo -e "\033[31m mode:put with non-expaned wildcard test failed \033[0m"
        eixt 200
    fi

    # ~~~~~~~~~~ local test summary
    echo -e "\033[32m All local tests passed! \033[0m"

    # ================== remote test if cluster specified (Must be set already in ~/ssh/.config)
    if [[ -n $1 ]]; then  #>- a remote cluster provided
        # ~~~~~~~~~~ check connection availability
        if [[ `ssh $1 "echo 123 && mkdir -p ~/.jsync_utest/r1/r2/L" 2>/dev/null` == "123" ]]; then
            echo "start to test via ssh based on given cluster"
        else
            echo "\033[31m Cannot ssh into provided host: $1, please check your ~/.ssh/config and make sure it can be login without any confirmation. \033[0m"
            exit 200
        fi

        # ~~~~~~~~~~ append remote project into .jsyncrc
        cat >> .jsyncrc << EOF
test2 $1:~/.jsync_utest
EOF
        # ~~~~~~~~~~ test logic
        mkdir r1 && cd $_
        # ... get remote files
        $exe -m get -t test2 r2/L
        # ... check local files
        if [[ -e r2/L ]]; then
            echo -e "\033[32m mode:get for remote test passed \033[0m"
        else
            echo -e "\033[31m mode:get for remote test failed \033[0m"
            exit 200
        fi
        # ~~~~~~~~~~ remove remote side-effect
        ssh $1 "rm -rf ~/.jsync_utest" 2>/dev/null
        # ~~~~~~~~~~ remote test Summary
        echo -e "\033[32m All remote tests passed! \033[0m"
    fi

    # ================== final hint
    echo -e "\033[33m run 'rm -rf .jsync_utest' to delete the utest directory \033[0m"
fi


#Requires -Version 7

# This script serves as a controller for files in r.o.b.s. system
# including several main functionality:
#    ● Split file/dir into Local/OneDrive/BaiduSYnc
#    ● Union file/dir from OneDrive/BaiduSync
#    ● Pack outdated directories into StaticRecall 

# 2023-12-25    init
# 2024-01-07    refined



###########################################################
# Preparation
###########################################################
# >>>>>>>>>>>>>>>>>>>> params resolve <<<<<<<<<<<<<<<<<<<<<
param (
    # [ValidateSet("sort", "show", "restore", "pack")]
    [string]$action,
    [string]$target,
    [Alias("h")]
    [switch]$help,
    [Alias("eo")]
    [switch]$echo_only,
    [switch]$error_stop,
    [Alias("v")]
    [switch]$verbose,
    [string]$restore_op
)


# >>>>>>>>>>>>>>>>>>>>> pre-settings <<<<<<<<<<<<<<<<<<<<<<
Import-Module rdee


# >>>>>>>>>>>>>>>>>>> global variables <<<<<<<<<<<<<<<<<<<<
# ================== r.o.b.s. root paths
$rrR = "D:\recRoot\Roadelse"
$rrO = "C:\Users\${env:UserName}\OneDrive\recRoot\Roadelse"
$rrB = "D:\BaiduSyncdisk\recRoot\Roadelse"
$rrS = "D:\recRoot\StaticRecall"

# ================== key variables in processing
# $errlog = "${target_dir}\resort-error." + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log"
$ignore_global = @(".reconf$", ".resync_config$", "resort-error\..*\.log$", "^prior\.", "^deprecated\.", ".obsidian")
[System.Collections.ArrayList]$sorted_dirs = @()


# >>>>>>>>>>>>>>>>>>>> pre-processing <<<<<<<<<<<<<<<<<<<<<


###########################################################
# kernel functions
###########################################################
# >>>>>>>>>>>>>>>>>>>>>>>>> entry <<<<<<<<<<<<<<<<<<<<<<<<<
# function main {
    
#     if ($mode.ToLower() -eq "sort"){
#         sort_dir @$PSBoundParameters
#     }

#     if ($restore_mode) {
#         restore_dir $target_dir ($restore_move ? "Move" : "Copy")
#     } elseif ($staticRecall) {
#         pack2StaticRecall $target_dir
#     } else {
#         sort_dir $target_dir
#     }
# }
# <L1> global help function
function show_help {
    param(
        [string]$action
    )
    if ($action -eq "") {
        Write-Output @"
[~] Usage
    robs.ps1 <action> [<target>] [options]

Supported actions:
    ● sort      robs.ps1 sort -h|--help
    ● restore   robs.ps1 restore -h|--help
    ● pack      robs.ps1 pack -h|--help
    ● show      robs.ps1 pack -h|--help

Global options:
    ● -eo, -echo_only
        Do not do the execution, but only echo the commands
    ● -h, -help
        Show the help information for this script
"@
    } elseif ($action -eq "sort") {
        Write-Output @"
        [~] Usage
            robs.ps1 sort [<target>] [options]
"@
    } else {
        Write-Error "Should Never be displayed!" -ErrorAction Stop
    }
}


function norm_path{
    param(
        [string]$target,
        [ValidateSet("skip", "mkdir", "stop")]
        [string]$no_exist_action="mkdir"
    )

# ================== set $pwd as default target if not specified
if ($target -eq "") {
    $target = "."
}


# ================== get target directory path
$target = [IO.Path]::GetFullPath($target, $pwd.ProviderPath)

if (Test-Path $target){
    if ((Get-Item $target).PSIsContainer) { #>- pass for directory
        # pass
    } elseif ((Get-Item $target).Name -eq ".reconf") {  #>- get directory path for .reconf
        $target = (Get-Item $target).DirectoryName
    } else { #>- error for file not being .reconf
        Write-Error "If a file is given, is must be a .reconf file!" -ErrorAction Stop
    }
}

# ================== convert all obs path to roadelse path, i.e., local path
if ($target.StartsWith($rrO)) {
    $rpath = $target.Replace($rrO, $rrR)
    $opath = $target
    $bpath = $target.Replace($rrO, $rrB)
    $spath = $target.Replace($rrO, $rrS)
} elseif ($target.StartsWith($rrB)) {
    $rpath = $target.Replace($rrB, $rrR)
    $opath = $target.Replace($rrB, $rrO)
    $bpath = $target
    $spath = $target.Replace($rrB, $rrS)
} elseif ($target.StartsWith($rrS)) {
    $rpath = $target.Replace($rrS, $rrR)
    $opath = $target.Replace($rrS, $rrO)
    $bpath = $target.Replace($rrS, $rrB)
    $spath = $target
} elseif ($target.StartsWith($rrR)) {
    $rpath = $target
    $opath = $target.Replace($rrR, $rrO)
    $bpath = $target.Replace($rrR, $rrB)
    $spath = $target.Replace($rrR, $rrS)
} else {  #>- Error if not within r.o.b.s. system
    Write-Error "Path not in r.o.b.s. system! $target" -ErrorAction Stop
}

# ================== check target existence
if (-not (Test-Path -Path $rpath)) {
    if ($no_exist_action -eq "mkdir"){
        New-Item -ItemType Directory $rpath -Force
    } elseif ($no_exist_action -eq "stop"){
        Write-Error "target path doesn't exist!" -ErrorAction Stop
    } 
}

    return $rpath, $opath, $bpath, $opath
}


# >>>>>>>>>>> sort content in target directory <<<<<<<<<<<<
function sort_dir {
    <# .SYNOPSIS
    This function aims to sort all files/directories in the target directory. That is, move files/dirs into OneDrive and BaiduSync paths and link them back based on several rules. 
    
    .PARAMETER wdir
    target working directory
    #>

    # ================== parameters definition
    param(
        $target,
        $rcf = @{},
        [Alias("h")]
        [switch]$help,
        [Parameter(ValueFromRemainingArguments = $true)]
        $_arg_holders
    )

    # Write-Output "Enter sort_dir $wdir"

    if ($help){
        show_help -action sort
        return
    }

    # ================== pre-processing
    # ~~~~~~~~~~ handle r.o.b. paths 
    $rpath, $opath, $bpath, $spath = norm_path $target
    # $wdir = Get-Item $robs_path[0]
    # if ($wdir -is [string]) {
        # if (-not(Test-Path $wdir)) { #>- for conditions that building local links in a new PC
            # New-Item -ItemType Directory $wdir -Force
        # }
        # $wdir = Get-Item $wdir;
    # }

    # $opath = l2o $wdir.FullName
    # $bpath = l2b $wdir.FullName

    # ~~~~~~~~~~ load .reconf if existed
    if (Test-Path "${rpath}\.reconf") {
        Update-Hashtable $rcf (Get-Content "${rpath}\.reconf" | ConvertFrom-Json -AsHashtable)
    }
    
    # ~~~~~~~~~~ check ignore_this and 
    if ($rcf.ignore_this) {
        return
    }

    # ~~~~~~~~~~ remark current target in global
    $sorted_dirs.Add($rpath.FullName.Replace($rrR + "\", "")) | Out-Null

    # ================== handle children items one by one
    Get-ChildItem $rpath | 
    ForEach-Object -Process {
        # ~~~~~~~~~~ ignore symlink
        if ($_.Attributes -match "ReparsePoint") {
            return
        }

        # Write-Output "processing $_"
        # ~~~~~~~~~~ check ignore_global
        foreach ($ig in $ignore_global) {
            if ($_.Name -match $ig) {
                return
            }
        }

        # ~~~~~~~~~~ check ignore list in rcf
        if ($rcf.Contains('ignore_list') -and $rcf.ignore_list.Contains($_.Name)) { #>- manual ignore
            return
        }

        # ~~~~~~~~~~ Do the operation via manually set rule
        if ($rcf.Contains('OneDrive') -and $rcf.OneDrive.Contains($_.Name)) {
            move_and_link $_ $_.FullName.Replace($rrR, $rrO)
            return
        } elseif ($rcf.Contains('Baidusync') -and $rcf.Baidusync.Contains($_.Name)) {
            move_and_link $_ $_.FullName.Replace($rrR, $rrB)
            return
        }

        # ~~~~~~~~~~ Do the operation via name prefix rule
        if ($_.Name.StartsWith("O..")) {
            move_and_link $_ $_.FullName.Replace($rrR, $rrO)
            return
        } elseif ($_.Name.StartsWith("B..")) {
            move_and_link $_ $_.FullName.Replace($rrR, $rrB)
            return
        }

        # ~~~~~~~~~~ handle children dir recursively
        if ($_.PSIsContainer) {
            sort_dir -target $_ -rcf (deepcopy $rcf)

        # ~~~~~~~~~~ Do the operation in default rules
        } else {
            $fsize = $_.Length / 1MB; # file size in MB
            if ($fsize -lt 5) {
                move_and_link $_ $_.FullName.Replace($rrR, $rrO)
            } elseif ($fsize -lt 200) {
                move_and_link $_ $_.FullName.Replace($rrR, $rrB)
            }
        }
        # exit 0
    }

    # ================== link back items in OneDrive
    if (Test-Path $opath) {
        Get-ChildItem $opath | ForEach-Object -Process {
            $_lp = o2l $_.FullName  #>- corresponding local path for $_.FullName
            if (Test-Path $_lp) {
                # ~~~~~~~~~~ handle shortcut links separately (should only in onedrive!)
                if ($_lp.EndsWith(".lnk") -and (-not (Test-Path $_lp))) {
                    Copy-Item -Path $_.FullName -Destination $_lp
                    continue
                }

                # ~~~~~~~~~~ handle error conditions
                $i_lp = Get-Item $_lp
                if (-not ($i_lp.Attributes -match "ReparsePoint")) {
                    if ($i_lp.PSIsContainer) {
                        if (-not $sorted_dirs.Contains($_lp.Replace($rrR + "\", ""))) {
                            errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                        }
                    } else {
                        errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                    }
                }
            } else {
                # ~~~~~~~~~~ do the link operation
                if ($verbose) {
                    Write-Output ("link OneDrive item: " + $_lp.Replace($rrR + "\", "") + " to Local")
                }
                New-Item -ItemType SymbolicLink -Path $_lp -Target $_.FullName
            }
        }
    }

    # ================== link back items in BaiduSync
    if (Test-Path $bpath) {
        Get-ChildItem $bpath | ForEach-Object -Process {
            Assert (-not $_.FullName.EndsWith(".lnk")) "Shortcut links should not occur in BaiduSync!" #>- ensure no shortcut link
            $_lp = b2l $_.FullName  #>- corresponding local path for $_.FullName
            if (Test-Path $_lp) {
                # ~~~~~~~~~~ handle error conditions
                $i_lp = Get-Item $_lp
                if (-not ($i_lp.Attributes -match "ReparsePoint")) {
                    if ($i_lp.PSIsContainer) {
                        if (-not $sorted_dirs.Contains($_lp.Replace($rrR + "\", ""))) {
                            errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                        }
                    } else {
                        errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                    }
                }
            } else {
                # ~~~~~~~~~~ do the link operation
                if ($verbose) {
                    Write-Output ("link BaiduSync item: " + $_lp.Replace($rrR + "\", "") + " to Local")
                }
                New-Item -ItemType SymbolicLink -Path $_lp -Target $_.FullName
            }
        }
    }
}


# >>>>>>>>>>>>>>>>> execution in sort_dir <<<<<<<<<<<<<<<<<
function move_and_link([object]$src, [string]$dst) {
    Write-Output "move_and_link($src, $dst)"

    # ================== ensure $dst doesn't exist
    if (Test-Path $dst) {
        errHandler "Destination already exists! $dst"
    }
    if ($echo_only) {
        return
    }

    New-Item -ItemType Directory (Split-Path $dst) -Force > $null

    # ================== for shortcut, just copy it
    if ($src.Name.EndsWith(".lnk")) {
        Copy-Item -Path $src.FullName -Destination "$dst"
        return
    }

    # ================== move then link back
    Move-Item -Path $src.FullName -Destination $dst
    New-Item -ItemType SymbolicLink -Path $src.FullName -Target $dst > $null
    
    # exit 0
}


# >>>>>>>>>>>>>>>>>>>> pack dir to SR <<<<<<<<<<<<<<<<<<<<<
function pack2StaticRecall {
    # ================== param resolve
    param(
        [Parameter(Mandatory = $true)]
        [string]$target
    )

    # ================== pre-processing
    $rpath, $opath, $bpath, $spath = norm_path $target -no_exist_action stop

    Assert ((Get-Item $rpath).PSIsContainer) "Path is not a directory! $rpath"

    $sr_path = ($rpath + ".zip").Replace($rrR, $rrS)

    restore_dir $rpath -mc "Move"

    if ($echo_only) {
        Write-Output "compress & delete, move .zip to StaticRecall"
        return
    }

    # ================== do the operation
    Compress-Archive -Path $rpath -DestinationPath ($rpath + ".zip") -CompressionLevel Fastest
    Remove-Item $rpath -Recurse -Force
    New-Item -ItemType Directory -Path (Split-Path $sr_path) -Force
    Move-Item -Path ($rpath + ".zip") -Destination $sr_path
}


# >>>>>>>>>>>>>>> gather files back to <r.> <<<<<<<<<<<<<<<
function restore_dir {
    # ================== param resolve
    [CmdletBinding()]
    param (
        [string]$target,
        [ValidateSet("Move", "Copy")] #>- case-insensitive by default , "move", "copy", "MOVE", "copy")]
        [string]$restore_op = "Copy"
    )

    # ================== pre-processing
    $rpath, $opath, $bpath, $spath = norm_path $target

    if ($echo_only) {
        Write-Output "restore_dir($rpath, $restore_op)"
        return
    }

    # ================== handle <r.> items one by one
    Get-ChildItem $rpath | 
    ForEach-Object -Process {
        if ($_.Attributes -match "ReparsePoint") {
            $tgt = $_.Target
            if (-not ($tgt.StartsWith($rrO) -or $tgt.StartsWith($rrB))) {
                return
            }
            Remove-Item $_
            if ($restore_op.ToUpper() -eq "MOVE") {
                Move-Item -Path $tgt -Destination $_.FullName
            } else {
                Copy-Item -Path $tgt -Destination $_.FullName -Recurse
            }
        } elseif ($_.PSIsContainer) { #>- for directory
            restore_dir $_ $restore_op
        } elseif ($_.Name.EndsWith(".lnk")) { #>- For Shortcut links
            if ($restore_op.ToUpper() -eq "MOVE") {
                Remove-Item $_.FullName.Replace($rrR, $rrO)
            }
        }
    }

    # ================== handle <o.> items one by one
    if (Test-Path $opath) {
        $nFilesO = (Get-ChildItem -Path $opath -Recurse -File | Measure-Object).Count
        if ($nFilesO -gt 0) {
            Write-Host "$nFilesO remained in OneDrive: $opath" -ForegroundColor ($restore_move ? "Red" : "Yellow")
        } else {
            Remove-Item $opath -Recurse -Force
        }
    }

    # ================== handle <b.> items one by one
    if (test-path $bpath) {
        $nFilesB = (Get-ChildItem -Path $bpath -Recurse -File | Measure-Object).Count
        if ($nFilesB -gt 0) {
            Write-Host "$nFilesO remained in Baidusync: $bpath" -ForegroundColor ($restore_move ? "Red" : "Yellow")
        } else {
            Remove-Item $bpath -Recurse -Force
        }
    }
}


# >>>>>>>>>>>>>>>> error handler function <<<<<<<<<<<<<<<<<
function errHandler {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$errmsg
    )
    Write-Error "Error: $errmsg" ($error_stop ? (-ErrorAction Stop) : (-ErrorAction continue))
}


# >>>>>>>>>>>>>>>> path-transfer functions <<<<<<<<<<<<<<<<
function l2o {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )
    return $ldir.Replace($rrR, $rrO)
}

function o2l {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    ) 

    return $ldir.Replace($rrO, $rrR)
}

function l2b {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )

    return $ldir.Replace($rrR, $rrB)
}

function b2l {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )

    return $ldir.Replace($rrB, $rrR)
}




###########################################################
# Function Caller
###########################################################
if ($action.ToLower() -eq "sort"){
    sort_dir @PSBoundParameters
} elseif ($action.ToLower() -eq "restore"){
    restore_dir @PSBoundParameters
} elseif ($action.ToLower() -eq "pack"){
    pack2StaticRecall @PSBoundParameters
} elseif ($action.ToLower() -eq "show"){
    show_robs @PSBoundParameters
} else {
    show_help
}
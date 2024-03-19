#Requires -Version 7

# This script serves as a controller for files in r.o.b.s. system
# including several main functionality:
#    ● Split file/dir into Local/OneDrive/BaiduSYnc
#    ● Union file/dir from OneDrive/BaiduSync
#    ● Pack outdated directories into StaticRecall 

# 2023-12-25    init
# 2024-01-08    rebuild, use 1st argument as action, pointing to corresponding functions. Action now supports: sort, restore, pack, show



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
    # ... for action:restore
    [string]$restore_op,
    # ... for action:show
    [string]$goto,
    [switch]$open
)


# >>>>>>>>>>>>>>>>>>>>> pre-settings <<<<<<<<<<<<<<<<<<<<<<
Import-Module rdee


# >>>>>>>>>>>>>>>>>>> global variables <<<<<<<<<<<<<<<<<<<<
# ================== r.o.b.s. root paths
$rrR = "D:\recRoot\Roadelse"
$rrO = "${env:USERPROFILE}\OneDrive\recRoot\Roadelse"
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
# >>>>>>>>>>>>>>>>>>>>> help function <<<<<<<<<<<<<<<<<<<<<
function show_help {
    param(
        [string]$action
    )

    # ================== show help info. based on action
    if ($action -eq "") {
        Write-Output @"
[~] Usage
    robs.ps1 <action> [target] [options]

Supported actions:
    ● sort      robs.ps1 sort -h
    ● restore   robs.ps1 restore -h
    ● pack      robs.ps1 pack -h
    ● show      robs.ps1 pack -h
    ● rename    robs.ps1 rename -h

Global options:
    ● -eo, -echo_only
        Do not do the execution, but only echo the commands
    ● -v, -verbose
        Print all detailed messages
    ● -h, -help
        Show the help information for this script
"@
    }
    elseif ($action -eq "sort") {
        Write-Output @"
robs.ps1 for action:sort, aims to sort file & directories among r.o.b.s. To be specific, based on local Roadelse/ (r.), move suitable items to OneDrive/BaiduSync and link them back, or directly link back in a new host.

[~] Usage
    robs.ps1 sort [target] [options]

[target]    any directory or file:.reconf within r.o.b.s. projects. use "." if not specified
[options]
    ● -h | -help
        Show the hepl info. for action:sort
    ● See global options in "robs.ps1 -h"
"@
    }
    elseif ($action -eq "restore") {
        Write-Output @"
robs.ps1 for action:restore, aims to gather all items from Onedrive/Baidusync, via "move" or "copy"

[~] Usage
    robs.ps1 restore [target] [options]

[target]    any directory or file:.reconf within r.o.b.s. projects. use "." if not specified
[options]
    ● -h | -help
        Show the hepl info. for action:restore
    ● -op | -restore_op, default("Move"), validateSet("Move", "Copy")
        Choose transfer operation
    ● See global options in "robs.ps1 -h"

"@
    }
    elseif ($action -eq "pack") {
        Write-Output @"
robs.ps1 for action:pack, aims to package target dir and move it to StaticRecall

[~] Usage
    robs.ps1 pack [target] [options]

[target]    any directory or file:.reconf within r.o.b.s. projects. use "." if not specified
[options]
    ● -h | -help
        Show the hepl info. for action:restore
    ● See global options in "robs.ps1 -h"

"@
    }
    elseif ($action -eq "show") {
        Write-Output @"
robs.ps1 for action:show, aims to show correspoinding robs paths and provide relative operations

[~] Usage
    robs.ps1 show [target] [options]

[target]    any directory or file:.reconf within r.o.b.s. projects. use "." if not specified
[options]
    ● -h | -help
        Show the hepl info. for action:restore
    ● -goto, combine(r,o,b,s,a)
        go to target path in shell, detecting the 1st valid char
    ● -open
        if set to $true, -goto will open file explorers for all valid (r,o,b,s,a) paths
    ● See global options in "robs.ps1 -h"

"@
    }
    elseif ($action -eq "rename") {
        Write-Output @"
robs.ps1 for action:rename, aims to rename file and its symlinks simultaneously

[~] Usage
    robs.ps1 rename <target> <newname> [options]

<target>    any existed directory or file
<newname>   new name
[options]
    ● -h | -help
        Show the hepl info. for action:restore
    ● See global options in "robs.ps1 -h"

"@
    }
    else {
        Write-Error "Should Never be displayed!" -ErrorAction Stop
    }
}


# >>>>>>>>>>>> normalize target path and check <<<<<<<<<<<<
function norm_path {
    param(
        [string]$target,
        [ValidateSet("skip", "mkdir", "stop")]
        [string]$no_exist_action = "mkdir"
    )

    # ================== set $pwd as default target if not specified
    if ($target -eq "") {
        $target = "."
    }


    # ================== get target directory path
    $target = [IO.Path]::GetFullPath($target, $pwd.ProviderPath)

    if (Test-Path $target) {
        if ((Get-Item $target).PSIsContainer) {
            #>- pass for directory
            # pass
        }
        elseif ((Get-Item $target).Name -eq ".reconf") {
            #>- get directory path for .reconf
            $target = (Get-Item $target).DirectoryName
        }
        else {
            #>- error for file not being .reconf
            Write-Error "If a file is given, is must be a .reconf file!" -ErrorAction Stop
        }
    }

    # ================== convert all obs path to roadelse path, i.e., local path
    if ($target.StartsWith($rrO)) {
        $rpath = $target.Replace($rrO, $rrR)
        $opath = $target
        $bpath = $target.Replace($rrO, $rrB)
        $spath = $target.Replace($rrO, $rrS)
    }
    elseif ($target.StartsWith($rrB)) {
        $rpath = $target.Replace($rrB, $rrR)
        $opath = $target.Replace($rrB, $rrO)
        $bpath = $target
        $spath = $target.Replace($rrB, $rrS)
    }
    elseif ($target.StartsWith($rrS)) {
        $rpath = $target.Replace($rrS, $rrR)
        $opath = $target.Replace($rrS, $rrO)
        $bpath = $target.Replace($rrS, $rrB)
        $spath = $target
    }
    elseif ($target.StartsWith($rrR)) {
        $rpath = $target
        $opath = $target.Replace($rrR, $rrO)
        $bpath = $target.Replace($rrR, $rrB)
        $spath = $target.Replace($rrR, $rrS)
    }
    else {
        #>- Error if not within r.o.b.s. system
        Write-Error "Path not in r.o.b.s. system! $target" -ErrorAction Stop
    }

    # ================== check target existence || !! Need rebuld for conditions that file only lie in o.sys
    if (-not (Test-Path -Path $rpath)) {
        if ($no_exist_action -eq "mkdir") {
            New-Item -ItemType Directory $rpath -Force
        }
        elseif ($no_exist_action -eq "stop") {
            Write-Error "target path doesn't exist!" -ErrorAction Stop
        } 
    }

    return $rpath, $opath, $bpath, $spath
}


# >>>>>>>>>>>>>>>>> show & operate paths <<<<<<<<<<<<<<<<<<
function show_robs {
    param(
        $target,
        [Alias("h")]
        [switch]$help,
        [string]$goto,
        [switch]$open,
        [Parameter(ValueFromRemainingArguments = $true)]
        $_arg_holders
    )

    [void]$_arg_holders  #>- avoid unused variable hint in editor

    if ($help) {
        show_help -action show
        return
    }

    $rpath, $opath, $bpath, $spath = norm_path $target

    # ================== render √ and × char with ANSI color code
    function checkE {
        param(
            [string]$p
        )
        if (Test-Path $p) {
            return "`e[32m√`e[0m"
        }
        else {
            return "`e[31m×`e[0m"
        }
    }

    # ================== print paths
    Write-Host @"
Roadelse    `t($(checkE $rpath)) : $rpath
OneDrive    `t($(checkE $opath)) : $opath
BaiduSync   `t($(checkE $bpath)) : $bpath
StaticRecall`t($(checkE $spath)) : $spath
"@

    # ================== handle $goto param
    if ($goto) {
        [System.Collections.ArrayList]$dirs2go = @()
        if ($goto -match "a") {
            $dirs2go = $rpath, $opath, $bpath, $spath
        }
        else {
            if ($goto -match "r") {
                $dirs2go.Add($rpath) > $null
            }
            if ($goto -match "o") {
                $dirs2go.Add($opath) > $null
            }
            if ($goto -match "b") {
                $dirs2go.Add($bpath) > $null
            }
            if ($goto -match "s") {
                $dirs2go.Add($spath) > $null
            }
        }
        # Write-Output $dirs2go

        if ($goto.Count -eq 0) {
            Write-Error "Error! param:`$goto doesn't contain any of r, o, b, s, a" -ErrorAction Stop
        }
        
        # ~~~~~~~~~~ if $open, open the file explorer
        if ($open) {
            $dirs2go | ForEach-Object {
                Invoke-Item $_
            } 
        }
        else {
            #>- or just cd
            Set-Location $dirs2go[0]
        }
    }
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

    [void]$_arg_holders  #>- avoid unused variable hint in editor

    # Write-Output "Enter sort_dir $wdir"

    if ($help) {
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

    # $opath = r2o $wdir.FullName
    # $bpath = r2b $wdir.FullName

    # ~~~~~~~~~~ load .reconf if existed
    if (Test-Path "${rpath}\.reconf") {
        if (-not ((Get-Item "${rpath}\.reconf").Attributes -match "ReparsePoint")) {
            #>- added @2024-01-11
            move_and_link (Get-Item "${rpath}\.reconf") $opath\.reconf
        }
        Update-Hashtable $rcf (Get-Content "${rpath}\.reconf" | ConvertFrom-Json -AsHashtable)
    }
    
    # ~~~~~~~~~~ check ignore_this and 
    if ($rcf.ignore_this) {
        return
    }

    # ~~~~~~~~~~ remark current target in global
    $sorted_dirs.Add($rpath.Replace($rrR + "\", "")) | Out-Null

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
        if ($rcf.Contains('ignore_list') -and $rcf.ignore_list.Contains($_.Name)) {
            #>- manual ignore
            return
        }

        # ~~~~~~~~~~ Do the operation via manually set rule
        if ($rcf.Contains('OneDrive') -and $rcf.OneDrive.Contains($_.Name)) {
            move_and_link $_ (r2o $_.FullName)
            return
        }
        elseif ($rcf.Contains('Baidusync') -and $rcf.Baidusync.Contains($_.Name)) {
            move_and_link $_ (r2b $_.FullName)
            return
        }

        # ~~~~~~~~~~ Do the operation via name prefix rule
        if ($_.Name.StartsWith("O..")) {
            Write-Output "`e[33mRename`e[0m $($_.Name), following move_and_link would use original name"
            $newName = $_.Name.Replace("O..", "")
            $newPath = (Split-Path $_) + "\$newName"
            $ftemp = $_
            # Write-Output newPath=$newPath
            if (-not $echo_only) {
                Rename-Item $_.FullName -NewName $newName
                $ftemp = Get-Item $newPath
            }
            move_and_link $ftemp (r2o $newPath)
            return
        }
        elseif ($_.Name.StartsWith("B..")) {
            Write-Output "`e[33mRename`e[0m $($_.Name), following move_and_link would use original name"
            $newName = $_.Name.Replace("B..", "")
            $newPath = $_.DirectoryName + "/$newName"
            $ftemp = $_
            if (-not $echo_only) {
                Rename-Item $_.FullName -NewName $newName
                $ftemp = Get-Item $newPath
            }
            move_and_link $ftemp (r2b $newPath)
            return
        }

        # ~~~~~~~~~~ handle children dir recursively
        if ($_.PSIsContainer) {
            sort_dir -target $_ -rcf (deepcopy $rcf)

            # ~~~~~~~~~~ Do the operation in default rules
        }
        else {
            $fsize = $_.Length / 1MB; # file size in MB
            if ($fsize -lt 5) {
                move_and_link $_ $_.FullName.Replace($rrR, $rrO)
            }
            elseif ($fsize -lt 200) {
                move_and_link $_ $_.FullName.Replace($rrR, $rrB)
            }
        }
        # exit 0
    }

    # ================== link back items in OneDrive
    if (Test-Path $opath) {
        Get-ChildItem $opath | ForEach-Object -Process {
            $_lp = o2r $_.FullName  #>- corresponding local path for $_.FullName
            if (Test-Path $_lp) {
                # ~~~~~~~~~~ handle shortcut links separately (should only in onedrive!)
                if ($_lp.EndsWith(".lnk") -and (-not (Test-Path $_lp))) {
                    Write-Host "`e[33mCopy-Item shortcut`e[0m from OneDrive to local Roadelse: $($_.Name)"
                    if (-not $echo_only) {
                        Copy-Item -Path $_.FullName -Destination $_lp
                    }
                    continue
                }

                # ~~~~~~~~~~ handle error conditions
                $i_lp = Get-Item $_lp
                if (-not ($i_lp.Attributes -match "ReparsePoint")) {
                    if ($i_lp.PSIsContainer) {
                        if (-not $sorted_dirs.Contains($_lp.Replace($rrR + "\", ""))) {
                            errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                        }
                    }
                    else {
                        errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                    }
                }
            }
            else {
                # ~~~~~~~~~~ do the link operation
                Write-Host ("`e[33mlink`e[0m OneDrive item: " + $_lp.Replace($rrR + "\", "") + " to Local")
                if (-not $echo_only) {
                    New-Item -ItemType SymbolicLink -Path $_lp -Target $_.FullName
                }
            }
        }
    }

    # ================== link back items in BaiduSync
    if (Test-Path $bpath) {
        Get-ChildItem $bpath | ForEach-Object -Process {
            Assert (-not $_.FullName.EndsWith(".lnk")) "Shortcut links should not occur in BaiduSync!" #>- ensure no shortcut link
            $_lp = b2r $_.FullName  #>- corresponding local path for $_.FullName
            if (Test-Path $_lp) {
                # ~~~~~~~~~~ handle error conditions
                $i_lp = Get-Item $_lp
                if (-not ($i_lp.Attributes -match "ReparsePoint")) {
                    if ($i_lp.PSIsContainer) {
                        if (-not $sorted_dirs.Contains($_lp.Replace($rrR + "\", ""))) {
                            errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                        }
                    }
                    else {
                        errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                    }
                }
            }
            else {
                # ~~~~~~~~~~ do the link operation
                Write-Host ("`e[33mlink`e[0m BaiduSync item: " + $_lp.Replace($rrR + "\", "") + " to Local")
                if (-not $echo_only) {
                    New-Item -ItemType SymbolicLink -Path $_lp -Target $_.FullName
                }
            }
        }
    }
}


# >>>>>>>>>>>>>>>>> execution in sort_dir <<<<<<<<<<<<<<<<<
function move_and_link {

    param(
        [object]$src,
        [string]$dst,
        [string]$linkName
    )

    if ($linkName -eq "") {
        $linkName = $src.Name
    }
    $linkPath = (Split-Path $src.FullName) + "\$linkName"

    Write-Host "`e[33mmove_and_link`e[0m($src, $dst, $linkName)"

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
    New-Item -ItemType SymbolicLink -Path $linkPath -Target $dst > $null
    
    # exit 0
}


# >>>>>>>>>>>>>>> gather files back to <r.> <<<<<<<<<<<<<<<
function restore_dir {
    # ================== param resolve
    [CmdletBinding()]
    param (
        [string]$target,
        [ValidateSet("Move", "Copy")] #>- case-insensitive by default , "move", "copy", "MOVE", "copy")]
        [Alias("op")]
        [string]$restore_op = "Copy",
        [Alias("h")]
        [switch]$help,
        [Parameter(ValueFromRemainingArguments = $true)]
        $_arg_holders
    )

    [void]$_arg_holders  #>- avoid unused variable hint in editor

    if ($help) {
        show_help pack
        return
    }

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
            }
            else {
                Copy-Item -Path $tgt -Destination $_.FullName -Recurse
            }
        }
        elseif ($_.PSIsContainer) {
            #>- for directory
            restore_dir $_ $restore_op
        }
        elseif ($_.Name.EndsWith(".lnk")) {
            #>- For Shortcut links
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
        }
        else {
            Remove-Item $opath -Recurse -Force
        }
    }

    # ================== handle <b.> items one by one
    if (Test-Path $bpath) {
        $nFilesB = (Get-ChildItem -Path $bpath -Recurse -File | Measure-Object).Count
        if ($nFilesB -gt 0) {
            Write-Host "$nFilesO remained in Baidusync: $bpath" -ForegroundColor ($restore_move ? "Red" : "Yellow")
        }
        else {
            Remove-Item $bpath -Recurse -Force
        }
    }
}


# >>>>>>>>>>>>>>>>>>>> pack dir to SR <<<<<<<<<<<<<<<<<<<<<
function pack2StaticRecall {
    # ================== param resolve
    param(
        [Parameter(Mandatory = $true)]
        [string]$target,
        [Alias("h")]
        [switch]$help,
        [Parameter(ValueFromRemainingArguments = $true)]
        $_arg_holders
    )

    [void]$_arg_holders  #>- avoid unused variable hint in editor

    if ($help) {
        show_help pack
        return
    }

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


function rename {
    #@ prepare
    param(
        [string]$target,
        [string]$newname,
        [Alias("h")]
        [switch]$help,
        [Parameter(ValueFromRemainingArguments = $true)]
        $_arg_holders
    )

    
    [void]$_arg_holders  #>- avoid unused variable hint in editor

    if ($help) {
        show_help rename
        return
    }

    # ================== pre-processing
    $rpath, $opath, $bpath, $spath = norm_path $target

    if ($echo_only) {
        Write-Output "restore_dir($rpath, $restore_op)"
        return
    }

    #@ main
    if (Test-Path $opath) {
        if ((Get-Item "${opath}").Attributes -match "ReparsePoint") {
            Write-Error "opath cannot denote to a symlink file!" -ErrorAction Stop
        }
        Write-Output "`e[33mRename`e[0m $target to $newname in Onedrive"
        if (-not $echo_only) {
            Rename-Item -Path $opath -NewName $newname
        }
        if (Test-Path $rpath) {
            if (-not((Get-Item "${opath}").Attributes -match "ReparsePoint")) {
                Write-Error "rpath should be a symlink file if opath existed!" -ErrorAction Stop
            }
            
            $opath_new = $opath.Substring(0, $opath.Length - $target.Length) + $newname
            $rpath_new = $rpath.Substring(0, $rpath.Length - $target.Length) + $newname
            Write-Output "`e[33mre-link`e[0m symlink in r.sys due to rename"
            if (-not $echo_only) {
                Remove-Item $rpath
                New-Item -ItemType SymbolicLink -Path $rpath_new -Target $opath_new -Force > $null
            }
        }
    }
    elseif (Test-Path $bpath) {
        if ((Get-Item "${bpath}").Attributes -match "ReparsePoint") {
            Write-Error "bpath cannot denote to a symlink file!" -ErrorAction Stop
        }
        Write-Output "`e[33mRename`e[0m $target to $newname in Onedrive"
        if (-not $echo_only) {
            Rename-Item -Path $bpath -NewName $newname
        }
        if (Test-Path $rpath) {
            if (-not((Get-Item "${bpath}").Attributes -match "ReparsePoint")) {
                Write-Error "rpath should be a symlink file if bpath existed!" -ErrorAction Stop
            }
            
            $bpath_new = $bpath.Substring(0, $bpath.Length - $target.Length) + $newname
            $rpath_new = $rpath.Substring(0, $rpath.Length - $target.Length) + $newname
            Write-Output "`e[33mre-link`e[0m symlink in r.sys due to rename"
            if (-not $echo_only) {
                Remove-Item $rpath
                New-Item -ItemType SymbolicLink -Path $rpath_new -Target $bpath_new -Force > $null
            }
        }
    }
    elseif (Test-Path $rptah) {
        Write-Output "`e[33mre-link`e[0m symlink in r.sys due to rename"
        if (-not $echo_only) {
            Rename-Item -Path $rpath -NewName $newname
        }
    }
    else {
        Write-Error "$target doesn't exist in current directory for any of r/o/b system" -ErrorAction Stop
    }
}


# >>>>>>>>>>>>>>>> error handler function <<<<<<<<<<<<<<<<<
function errHandler {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$errmsg
    )
    Write-Error "Error: $errmsg" -ErrorAction ($error_stop ? "Stop" : "continue")
}


# >>>>>>>>>>>>>>>> path-transfer functions <<<<<<<<<<<<<<<<
function r2o {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )
    return $ldir.Replace($rrR, $rrO)
}

function o2r {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    ) 

    return $ldir.Replace($rrO, $rrR)
}

function r2b {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )

    return $ldir.Replace($rrR, $rrB)
}

function b2r {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )

    return $ldir.Replace($rrB, $rrR)
}




###########################################################
# Function entry
###########################################################
if ($action.ToLower() -eq "sort") {
    sort_dir @PSBoundParameters
}
elseif ($action.ToLower() -eq "restore") {
    restore_dir @PSBoundParameters
}
elseif ($action.ToLower() -eq "pack") {
    pack2StaticRecall @PSBoundParameters
}
elseif ($action.ToLower() -eq "show") {
    show_robs @PSBoundParameters
}
elseif ($action.ToLower() -eq "rename") {
    Write-Host $PSBoundParameters
    rename @PSBoundParameters
}
else {
    show_help
}

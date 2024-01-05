#Requires -Version 7

# This script serves as a controller for files in recRoot/Roadelse
# including several main functionality:
#    ● Split file/dir into Local/OneDrive/BaiduSYnc
#    ● Union file/dir from OneDrive/BaiduSync

# 2023-12-25    init


# >>>>>>>>>>>>>> params
param (
    [Alias("e")]
    [switch]$echo_only,
    [Alias("t")]
    [string]$target,
    [Alias("r")]
    [switch]$restore_mode,
    [Alias("rm")]
    [switch]$restore_move,
    [switch]$error_stop,
    [switch]$verbose,
    [Alias("sr")]
    [switch]$staticRecall
)

Import-Module rdee

# >>>>>>>>>>>>>> global variables and pre-check
$rrL = "D:\recRoot\Roadelse"
$rrO = "C:\Users\${env:UserName}\OneDrive\recRoot\Roadelse"
$rrB = "D:\BaiduSyncdisk\recRoot\Roadelse"
$rrS = "D:\recRoot\StaticRecall"

if ($target -eq "") {
    $target = "."
}

if (-not (Test-Path -Path $target)) {
    Write-Output "target path doesn't exist!"
    exit 1
}

$target_dir = (Get-Item $target).FullName
if ((Get-Item $target_dir).PSIsContainer) {
    # $target_dir = (Get-Item $target_dir).FullName
} elseif ((Get-Item $target).Name -eq ".reconf") {
    $target_dir = (Get-Item $target_dir).DirectoryName
} else {
    Write-Error "If a file is given, is must be a .reconf file!" -ErrorAction Stop
}

if ($target.FullName.StartsWith($rrO)) {
    $target_dir = $target_dir.Replace($rrO, $rrL)
} elseif ($target.FullName.StartsWith($rrB)) {
    $target_dir = $target_dir.Replace($rrB, $rrL)
} elseif ($target.FullName.StartsWith($rrS)) {
    $target_dir = $target_dir.Replace($rrS, $rrL)
} elseif ($target.FullName.StartsWith($rrL)) {
} else {
    Write-Error "Path not in r.o.b.s. system! $target_dir" -ErrorAction Stop
}

$errlog = "${target_dir}\resort-error." + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log"
$ignore_global = @(".reconf$", ".resync_config$", "resort-error\..*\.log$", "^prior\.", "^deprecated\.", ".obsidian")
[System.Collections.ArrayList]$sorted_dirs = @()

# >>>>>>>>>>>>>> core functions
function main {
    
    if ($restore_mode) {
        restore_dir $target_dir ($restore_move ? "Move" : "Copy")
    } elseif ($staticRecall) {
        pack2StaticRecall $target_dir
    } else {
        sort_dir $target_dir
    }
}


function sort_dir {
    # params:
    #    wdir - working directory

    param(
        [Parameter(Mandatory = $true)]
        $wdir,
        $rcf = @{}
    )

    # Write-Output "Enter sort_dir $wdir"

    # keep $wdir be an item object 
    if ($wdir -is [string]) {
        if (-not(Test-Path $wdir)) { #>- for conditions that building local links in a new PC
            New-Item -ItemType Directory $wdir -Force
        }
        $wdir = Get-Item $wdir;
    }

    $odir_path = l2o $wdir.FullName
    $bdir_path = l2b $wdir.FullName

    # load .reconf if existed
    if (Test-Path "${wdir}\.reconf") {
        Update-Hashtable $rcf (Get-Content "${wdir}\.reconf" | ConvertFrom-Json -AsHashtable)
    }
    
    # >>> check ignore_this
    if ($rcf.ignore_this) {
        return
    }
    $sorted_dirs.Add($wdir.FullName.Replace($rrL + "\", "")) | Out-Null

    # >>> check ignore_list & get target list
    Get-ChildItem $wdir | 
    ForEach-Object -Process {
        # 1. ignore symlink
        if ($_.Attributes -match "ReparsePoint") {
            return
        }

        # Write-Output "processing $_"
        # 2. check if ignore_this
        foreach ($ig in $ignore_global) {
            if ($_.Name -match $ig) {
                return
            }
        }

        if ($rcf.Contains('ignore_list') -and $rcf.ignore_list.Contains($_.Name)) { #>- manual ignore
            return
        }

        # 3. check manually set Onedrive / Baidusync (no-condition)
        if ($rcf.Contains('OneDrive') -and $rcf.OneDrive.Contains($_.Name)) {
            move_and_link $_ $_.FullName.Replace($rrL, $rrO)
            return
        } elseif ($rcf.Contains('Baidusync') -and $rcf.Baidusync.Contains($_.Name)) {
            move_and_link $_ $_.FullName.Replace($rrL, $rrB)
            return
        }

        # 4. check FDs with specific prefix O.. or B..
        if ($_.Name.StartsWith("O..")) {
            move_and_link $_ $_.FullName.Replace($rrL, $rrO)
            return
        } elseif ($_.Name.StartsWith("B..")) {
            move_and_link $_ $_.FullName.Replace($rrL, $rrB)
            return
        }

        # 5. split File/Directory
        if ($_.PSIsContainer) {
            sort_dir -wdir $_ -rcf (deepcopy $rcf)
        } else {
            $fsize = $_.Length / 1MB; # file size in MB
            if ($fsize -lt 5) {
                move_and_link $_ $_.FullName.Replace($rrL, $rrO)
            } elseif ($fsize -lt 200) {
                move_and_link $_ $_.FullName.Replace($rrL, $rrB)
            }
        }
        # exit 0
    }

    if (Test-Path $odir_path) {
        Get-ChildItem $odir_path | ForEach-Object -Process {
            $_lp = o2l $_.FullName  #>- corresponding local path for $_.FullName
            if (Test-Path $_lp) {
                # --- handle shortcut links separately (should only in onedrive!)
                if ($_lp.EndsWith(".lnk") -and (-not (Test-Path $_lp))) {
                    Copy-Item -Path $_.FullName -Destination $_lp
                    continue
                }

                $i_lp = Get-Item $_lp
                if (-not ($i_lp.Attributes -match "ReparsePoint")) {
                    if ($i_lp.PSIsContainer) {
                        if (-not $sorted_dirs.Contains($_lp.Replace($rrL + "\", ""))) {
                            errHandler ("File conflict: " + $_lp.Replace($rrL + "\", ""))
                        }
                    } else {
                        errHandler ("File conflict: " + $_lp.Replace($rrL + "\", ""))
                    }
                }
            } else {
                if ($verbose) {
                    Write-Output ("link OneDrive item: " + $_lp.Replace($rrL + "\", "") + " to Local")
                }
                New-Item -ItemType SymbolicLink -Path $_lp -Target $_.FullName
            }
        }
    }

    if (Test-Path $bdir_path) {
        Get-ChildItem $bdir_path | ForEach-Object -Process {
            Assert (-not $_.FullName.EndsWith(".lnk")) "Shortcut links should not occur in BaiduSync!" #>- ensure no shortcut link
            $_lp = b2l $_.FullName  #>- corresponding local path for $_.FullName
            if (Test-Path $_lp) {
                $i_lp = Get-Item $_lp
                if (-not ($i_lp.Attributes -match "ReparsePoint")) {
                    if ($i_lp.PSIsContainer) {
                        if (-not $sorted_dirs.Contains($_lp.Replace($rrL + "\", ""))) {
                            errHandler ("File conflict: " + $_lp.Replace($rrL + "\", ""))
                        }
                    } else {
                        errHandler ("File conflict: " + $_lp.Replace($rrL + "\", ""))
                    }
                }
            } else {
                if ($verbose) {
                    Write-Output ("link BaiduSync item: " + $_lp.Replace($rrL + "\", "") + " to Local")
                }
                New-Item -ItemType SymbolicLink -Path $_lp -Target $_.FullName
            }
        }
    }
}

function pack2StaticRecall {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )

    $odir = l2o $ldir
    $bdir = l2b $ldir

    Assert (Test-Path $ldir) "Path doesn't exist! $ldir"
    Assert ((Get-Item $ldir).PSIsContainer) "Path is not a directory! $ldir"

    $sr_path = ($ldir + ".zip").Replace("recRoot\Roadelse", "recRoot\StaticRecall")

    restore_dir $ldir -mc "Move"

    if ($echo_only) {
        Write-Output "compress & delete, move .zip to StaticRecall"
        return
    }
    Compress-Archive -Path $ldir -DestinationPath ($ldir + ".zip") -CompressionLevel Fastest
    Remove-Item $ldir -Recurse -Force
    New-Item -ItemType Directory -Path (Split-Path $sr_path) -Force
    Move-Item -Path ($ldir + ".zip") -Destination $sr_path
}


function errHandler {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$errmsg
    )
    Write-Error "Error: $errmsg" ($error_stop ? (-ErrorAction Stop) : (-ErrorAction continue))
}

function move_and_link([object]$src, [string]$dst) {
    Write-Output "move_and_link($src, $dst)"

    # >>> ensure $dst doesn't exist
    if (Test-Path $dst) {
        errHandler "Destination already exists! $dst"
    }
    if ($echo_only) {
        return
    }

    New-Item -ItemType Directory (Split-Path $dst) -Force > $null

    # >>> for shortcut, just copy it
    if ($src.Name.EndsWith(".lnk")) {
        Copy-Item -Path $src.FullName -Destination "$dst"
        return
    }

    # >>> move then link back
    Move-Item -Path $src.FullName -Destination $dst
    New-Item -ItemType SymbolicLink -Path $src.FullName -Target $dst > $null
    
    # exit 0
}

function restore_dir {
    [CmdletBinding()]
    param (
        [string]$wdir,
        [ValidateSet("Move", "Copy")] #>- case-insensitive by default , "move", "copy", "MOVE", "copy")]
        [string]$mc = "Copy"
    )

    if ($echo_only) {
        Write-Output "restore_dir($wdir, $mc)"
        return
    }

    $wdir = $wdir -is [string] ? (Get-Item $wdir) : $wdir

    Get-ChildItem $wdir | 
    ForEach-Object -Process {
        if ($_.Attributes -match "ReparsePoint") {
            $tgt = $_.Target
            if (-not ($tgt.StartsWith($rrO) -or $tgt.StartsWith($rrB))) {
                return
            }
            Remove-Item $_
            if ($mc.ToUpper() -eq "MOVE") {
                Move-Item -Path $tgt -Destination $_.FullName
            } else {
                Copy-Item -Path $tgt -Destination $_.FullName -Recurse
            }
        } elseif ($_.PSIsContainer) { #>- for directory
            restore_dir $_ $mc
        } elseif ($_.Name.EndsWith(".lnk")) { #>- For Shortcut links
            if ($mc.ToUpper() -eq "MOVE") {
                Remove-Item $_.FullName.Replace($rrL, $rrO)
            }
        }
    }

    # if ($mc.ToUpper() -eq "MOVE") {  # To-be-considered, depend on how I handle the remained files @2023-12-26 11:31:04
    if (Test-Path (l2o $wdir)) {
        $nFilesO = (Get-ChildItem -Path (l2o $wdir) -Recurse -File | Measure-Object).Count
        if ($nFilesO -gt 0) {
            Write-Host ("$nFilesO remained in OneDrive: " + (l2o $wdir)) -ForegroundColor ($restore_move ? "Red" : "Yellow")
        } else {
            Remove-Item (l2o $wdir) -Recurse -Force
        }
    }
    if (test-path (l2b $wdir)) {
        $nFilesB = (Get-ChildItem -Path (l2b $wdir) -Recurse -File | Measure-Object).Count
        if ($nFilesB -gt 0) {
            Write-Host ("$nFilesO remained in Baidusync: " + (l2b $wdir)) -ForegroundColor ($restore_move ? "Red" : "Yellow")
        } else {
            Remove-Item (l2b $wdir) -Recurse -Force
        }
    }
    # }

}

function l2o {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )
    return $ldir.Replace($rrL, $rrO)
}

function o2l {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )

    return $ldir.Replace($rrO, $rrL)
}

function l2b {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )

    return $ldir.Replace($rrL, $rrB)
}

function b2l {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )

    return $ldir.Replace($rrB, $rrL)
}



main

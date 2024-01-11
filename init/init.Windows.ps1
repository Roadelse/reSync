#Requires -Version 7

# >>>>>>>>>>>>>>>>>>>>>>>>>>> [prepare]
$jsync_dir = [IO.Path]::GetFullPath("$PSScriptRoot/../jsync")
$robsys_dir = [IO.Path]::GetFullPath("$PSScriptRoot/../robsys")
# <<<


# >>>>>>>>>>>>>>>>>>>>>>>>>>> [bin]
$rdeeDir = "D:\XAPP\rdee"
$rdeeBin = "$rdeeDir\bin"
New-Item -ItemType Directory -Path $rdeeBin -Force > $null

New-Item -ItemType SymbolicLink -Path $rdeeBin/robs.ps1 -Target $robsys_dir/robs.ps1 -Force > $null

# <<<


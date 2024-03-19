# Changelog


* (?) 解决不同action对应的不同positional arguments的问题, 或许考虑rebuild via OOP?
* (?) 同步rename, 额, 或者说其实是rename完实体之后重新link, 搞了个函数rename, 但是先注释了
* (?) 把一个folder从OneDrive给sort回Roadelse的时候, 如何控制每个folder是全部link回来还是直接创建folder然后再link里面的文件
* (√) 2024-01-18   (robs.ps1) bug fix: `($error_stop ? (-ErrorAction Stop) : (-ErrorAction continue))`, 提取-ErrorAction到三元表达式的外面
* (√) 2024-01-18   `$rrO`变量定义更新, 避免`$env:username`与`C:\Users\`下文件夹的命名不一样的问题

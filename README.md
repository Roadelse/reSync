# rdSync
synchronize files among Linux hosts, with binding directories specified along the path

规划 : 手动传输文件 → 手动同步文件 → 自动同步文件

目前仍位于第一步

***
***
# readme

## v0.1.2

+ 本地多路径的快速切换(主要是考虑多个同步盘协同工作的场景, 文件全分散), 后续支持同步功能(但是同步盘又不能用symlink...)
+ 和若干远程目标地址绑定的快速数据传输功能, 暂时不支持sync, 尽管名字叫sync

```
Usage:
  rdsync [options] files
  options:
    -m mode   , can be get, put and put2 (auto create missing directories), default put
    -c config , specify config filename, default ".rdsync_config"
    -t target , specify target machine:address, default any (i.e., the 1st)

  rob [options] target
    target : r(recRoot)/o(OneDrive)/b(BaiduSync)
    options : 
      -c, create the target directory if not existed
```

put的话可以多文件, get的话请用通配符, 同时别让他在本地就展开了! (没文件或者加单引号最保险)



***
***

# Changelog

## v0.1.2

添加`rob`指令对本地多路径的快速切换(与自动化创建)

## v0.1.1

add 'showmode (-s)' to show the config file

## v0.1

init, 最基本的数据来回传输, 但是支持自动创建dir, 这个还是有点用
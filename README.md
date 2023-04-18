# rdSync
synchronize files among Linux hosts, with binding directories specified along the path

规划 : 手动传输文件 → 手动同步文件 → 自动同步文件

目前仍位于第一步

***
***
# readme

## v0.1

和若干远程目标地址绑定的快速数据传输功能, 暂时不支持sync, 尽管名字叫sync

```
Usage:
  rdsync [options] files
  options:
    -m mode   , can be get, put and put2 (auto create missing directories), default put
    -c config , specify config filename, default ".rdsync_config"
    -t target , specify target machine:address, default any (i.e., the 1st)
```

put的话可以多文件, get的话请用通配符, 同时别让他在本地就展开了! (没文件或者加单引号最保险)



***
***

# Changelog

## v0.1

init, 最基本的数据来回传输, 但是支持自动创建dir, 这个还是有点用
# bash-stl

This is a standard library of sorts for BASH scripting on Linux.

`WORK IN PROGRESS`

### Building

See [https://github.com/chlorm/shell-packer](https://github.com/chlorm/shell-packer)

### Dependencies

-   bash >=4.2 [required] (core)
-   bc (conv)
-   coreutils/busybox
    -   dirname (os)
    -   grep (path)
    -   ln (os)
    -   mkdir (os)
    -   mktemp (args)
    -   readlink (os,path)
    -   rm (os)
    -   sort (math)
    -   touch (os)
    -   uniq (math)
    -   unlink (os)
-   curl (net)
-   lsb_relase [optional] (os)
-   lscpu (cpu)
-   sed (args)
-   uname [optional] (os)

# zig-pfs

extract PFS files from Artemis

reference/thank-you: [sakarie9/pfs_rs](https://github.com/sakarie9/pfs_rs)

tested on Clover Reset Demo

# build

```sh
$ ./build.sh
or
$ zig build-exe zpfs.zig
```

# usage

```sh
$ ./zpfs pfsfile # list file
$ ./zpfs pfsfile outdir
```

# note

might be hard to port because of MMAP_PRIVATE
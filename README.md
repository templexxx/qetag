# qetag
Qetag for Erlang

Maybe it's the fastest qetag program in Qiniu

使用的读文件方法是read，这样可以利用erlang的async thread，如果使用raw，它使用scheduler线程调用read,而且非常依赖GC，内存占用高，还可能导致整个scheduler卡住。


CPU核心数越多 跑的越快


USAGE:

make

etag:etag_file(File_path).


ps: 利用 erl +A 调整thread数量


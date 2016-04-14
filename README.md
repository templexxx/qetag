# qetag
Qetag for Erlang

Maybe it's the fastest qetag program in Qiniu

使用的读文件方法是read，这样可以利用erlang的async thread，如果使用raw，它使用scheduler线程调用read,而且非常依赖GC，内存占用高，还可能导致整个scheduler卡住。


CPU核心数越多 跑的越快


USAGE:

make

etag:etag_file(File_path).


ps: 利用 erl +A 调整thread数量

4.14

新增golang版本并行计算qetag

其中qetag.go为加入workerPool的版本

qetag2.go是由同事完成的直接起协程"不管不顾"的并发

在go1.6上qetag.go在速度上明显的要优于qetag2.go

这一方面是优于go在读文件时调用syscall本身IO并发数就是有限制的

"无原则"的IO并发显然加大了runtime system的调度难度和压力,而且容易导致IO卡住

我想这是为什么我在加入workerPool后性能更高的原因

对于早期版本的go qetag.go则被限制为单线程运行,而新版本则不会,这应该是由于go的运行时系统的进步导致的
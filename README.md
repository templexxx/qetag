# qetag
Qetag for Erlang

Maybe it's the fastest qetag program in Qiniu

https://github.com/qiniu/qetag

核心数越多 跑的越快
在自己的2core 4线程的机器上跑1.7GB的qetag耗时2.3S左右
在虚拟机8core 上跑4GB的qetag耗时1.3S左右  8个核心均有负载 最高在40%

对比同事用go写的并行计算的程序(他随便写着玩的)
在我自己的笔记本上跑上面那个1.7GB的耗时2.1S左右
在8 core虚拟机上跑上面那个4GB的耗时4S左右  8个核心均有负载  最高在99%

USAGE:

make

qetag:etag_file(Filename).
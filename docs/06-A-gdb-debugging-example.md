## An example of how to debug WebKit GTK with gdb from a WebKit container

1. Build WebKit from a container: `./Tools/Scripts/build-webkit --debug --gtk`
2. Run MiniBrowser, from above container, with some file to debug, e.g.:
```
./Tools/Scripts/run-minibrowser --debug --gtk LayoutTests/imported/w3c/web-platform-tests/css/css-fonts/lang-attribute-affects-rendering.html
```
3. Enter the same container in a different tab.
4. Find the logged `PID` of `WebKitWebProcess`, e.g. as follows:
```
mirko@wkdev:/host/home/mirko/work/code/WebKit$ ps -fA | grep -w "WebKitWebProcess\|PID"
UID          PID    PPID  C STIME TTY          TIME CMD
mirko      13460   13424  0 09:42 pts/0    00:00:00 /usr/bin/bwrap --args 34 -- /host/home/mirko/work/code/WebKit/WebKitBuild/GTK/Debug/bin/WebKitWebProcess 13 26 28
mirko      13461   13460  0 09:42 pts/0    00:00:02 /host/home/mirko/work/code/WebKit/WebKitBuild/GTK/Debug/bin/WebKitWebProcess 13 26 28
mirko      15736   13961  0 10:08 pts/1    00:00:00 grep --color=auto -w WebKitWebProcess\|PID
```
5. Attach gdb to the process:
```
gdb -p 13461
```
and wait a little, this may download some files. That may end with a warning but that won't prevent debugging:
```
[...]
Downloading separate debug info for system-supplied DSO at 0x7fff33477000
[Thread debugging using libthread_db enabled]
Using host libthread_db library "/usr/lib/x86_64-linux-gnu/libthread_db.so.1".
Download failed: Invalid argument.  Continuing without source file ./io/../sysdeps/unix/sysv/linux/poll.c.
0x00007b01163094cd in __GI___poll (fds=0x5c19f4ea9150, nfds=2, timeout=28649) at ../sysdeps/unix/sysv/linux/poll.c:29

warning: 29	../sysdeps/unix/sysv/linux/poll.c: No such file or directory
```
6. Set a breakpoint at some interesting function which is known to be called and continue, e.g.:
```
(gdb) b FontPlatformData::platformDataInit
Breakpoint 1 at 0x7b012a45ec83: file /host/home/mirko/work/code/WebKit/Source/WebCore/platform/graphics/skia/FontPlatformDataSkia.cpp, line 65.
(gdb) c
```
7. In the MiniBrowser, reload the tab, e.g. via CTRL+F5 to not reuse cached content. The`PID` of the tab will stay the same.
9. Observe that `gdb` hit the breakpoint:
```
Thread 1 "WebKitWebProces" hit Breakpoint 1, WebCore::FontPlatformData::platformDataInit (this=0x7fff3340fb10)
    at /host/home/mirko/work/code/WebKit/Source/WebCore/platform/graphics/skia/FontPlatformDataSkia.cpp:65
65	{
(gdb)

```
10. Examine the call stack, e.g. to learn the control flow of the code.

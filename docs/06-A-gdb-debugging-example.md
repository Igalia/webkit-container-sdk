## An example of how to debug WebKit GTK with gdb from a WebKit container

1. Add a `.gdbinit` file as described at https://docs.webkit.org/Build%20%26%20Debug/DebuggingOnTheCommandLine.html#setting-up-your-environment.
2. Add logging for the pid to the code intended to debug. E.g. to `SomeFile.cpp`:
```
#include <iostream>
[...]
SomeClass::SomeMethod() {
std::cout << "pid=" << getpid() << std::endl;
[...]
}
```
3. Build WebKit from a container: `./Tools/Scripts/build-webkit --debug --gtk`
4. Run MiniBrowser, from above container, with some file to debug, e.g.:
```
./Tools/Scripts/run-minibrowser --debug --gtk LayoutTests/imported/w3c/web-platform-tests/css/css-fonts/lang-attribute-affects-rendering.html
```
6. Enter the same container in a different tab and (mentioned at https://docs.webkit.org/Build%20%26%20Debug/DebuggingOnTheCommandLine.html#manually-debugging-webkit):
```
export DYLD_FRAMEWORK_PATH=WebKitBuild/Debug
```
6. Find the logged `pid`, e.g. `pid=18102`, and attach gdb to that process:
```
gdb -p 18102
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
7. Set a breakpoint at some interesting function which is known to be called and continue, e.g.:
```
(gdb) b FontPlatformData::platformDataInit
Breakpoint 1 at 0x7b012a45ec83: file /host/home/mirko/work/code/WebKit/Source/WebCore/platform/graphics/skia/FontPlatformDataSkia.cpp, line 65.
(gdb) c
````
8. In the MiniBrowser, reload the tab, e.g. via CTRL+F5 to not reuse cached content. The`pid` of the tab will stay the same.
9. Observe that `gdb` hit the breakpoint:
```
Thread 1 "WebKitWebProces" hit Breakpoint 1, WebCore::FontPlatformData::platformDataInit (this=0x7fff3340fb10)
    at /host/home/mirko/work/code/WebKit/Source/WebCore/platform/graphics/skia/FontPlatformDataSkia.cpp:65
65	{
(gdb)

```
10. Examine the call stack, e.g. to learn the control flow of the code.

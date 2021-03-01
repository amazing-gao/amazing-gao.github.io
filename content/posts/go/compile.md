---
title: "Go工具链之compile初探"
slug: /go/compile
description: 介绍go compile命令以及编译指令
date: 2021-02-24T23:48:08+08:00
type: posts
draft: false
toc: true
featured: true
categories:
  - go
tags:
  - go
  - compile
series:
  - Go工具链
---

在阅读 Go 源代码的过程，可以看到大量形如 `//go:xxx` 的注释，虽然很容易猜测到肯定是和编译相关的，但并不清晰，于是就想深入了解一下。

在日常编译可执行文件的过程中，我想大家使用最多的毫无疑问是 `go build` 。只需一行命令即可将庞大且复杂的项目源代码编译成可执行文件，Go 把复杂的编译过程设计的非常简单、友好。
但是其实 Go 和 C/C++ 一样，也分为 compile 和 link 两个过程，今天我们要讲的就是 compile 过程。

## 自举
Go 在 1.5 之前使用 C 实现编译器，在 1.5 实现了[自举](https://en.wikipedia.org/wiki/Bootstrapping_/(compilers/))，也就是说 Go 的编译器是使用 Go 语言本身去实现的。
自举对编程语言来说是个里程碑，实现自举包括但不限于以下的好处：
* 语言通过自我编译、自我迭代，达到本身语言的真正成熟稳定
* 对编译器后端的优化不仅会优化以后所有编译出来的其它程序的效率，也会优化编译器本身的效率
* 使开发编译器的环境和使用这门语言开发的其它程序一致
* 摆脱其它语言的依赖和自我迭代

## 编译命令
Go 程序源码的编译可以通过以下命令行执行 `go tool compile [flags] file...`，简单来说该命令可以将同一个 *package* 的多个文件编译成一个 `.o` 文件，多个 `.o` 文件又可以被链接成一个可执行文件。

![编译过程:inline](/posts/gocompile/compile.png)

下面我们以一个简单的 hello world 程序来举例。
```go
package main

import "fmt"

func main() {
	fmt.Println("hello world")
}
```

执行编译命令，可以得到 main.o 对象文件。是不是也非常简单？其实 compile 命令有不少的选项参数，可以用来控制编译过程，但我这里默认即可，如有兴趣可以查看官方 [Compile Command Line](https://golang.org/cmd/compile/#hdr-Command_Line) 。

```sh
go tool compile main.go
```

## 编译指令

除了编译命令之外，Go 还提供了编译指令。那么编译指令是什么呢？编译指令是可以控制编译器行为的命令。

在 Go 中编译指令通过注释的方式编写，为了和普通注释做出区别，编译指令注释的双斜杠之后必须要紧跟编译指令。

编译指令包含 `Line directives` 和 `//go:name` 两种形式：Line directives 是历史原因导致的特例，它通常出现在机器生成的代码中；`//go:name` 是工具链中定义的指令。



### go:noescape
The //go:noescape directive must be followed by a function declaration without a body (meaning that the function has an implementation not written in Go). It specifies that the function does not allow any of the pointers passed as arguments to escape into the heap or into the values returned from the function. This information can be used during the compiler's escape analysis of Go code calling the function.

### go:uintptrescapes
The //go:uintptrescapes directive must be followed by a function declaration. It specifies that the function's uintptr arguments may be pointer values that have been converted to uintptr and must be treated as such by the garbage collector. The conversion from pointer to uintptr must appear in the argument list of any call to this function. This directive is necessary for some low-level system call implementations and should be avoided otherwise.

### go:noinline
The //go:noinline directive must be followed by a function declaration. It specifies that calls to the function should not be inlined, overriding the compiler's usual optimization rules. This is typically only needed for special runtime functions or when debugging the compiler.

### go:norace
The //go:norace directive must be followed by a function declaration. It specifies that the function's memory accesses must be ignored by the race detector. This is most commonly used in low-level code invoked at times when it is unsafe to call into the race detector runtime.

### go:nosplit
The //go:nosplit directive must be followed by a function declaration. It specifies that the function must omit its usual stack overflow check. This is most commonly used by low-level runtime code invoked at times when it is unsafe for the calling goroutine to be preempted.

### go:linkname localname [importpath.name]
This special directive does not apply to the Go code that follows it. Instead, the //go:linkname directive instructs the compiler to use “importpath.name” as the object file symbol name for the variable or function declared as “localname” in the source code. If the “importpath.name” argument is omitted, the directive uses the symbol's default object file symbol name and only has the effect of making the symbol accessible to other packages. Because this directive can subvert the type system and package modularity, it is only enabled in files that have imported "unsafe".

### Line directives
行指令不是本文的重点，本文仅简单介绍一下格式。

支持以下几种格式：

    //line :line
    //line :line:col
    //line filename:line
    //line filename:line:col
    /*line :line*/
    /*line :line:col*/
    /*line filename:line*/
    /*line filename:line:col*/

Examples：

    //line foo.go:10      the filename is foo.go, and the line number is 10 for the next line
    //line C:foo.go:10    colons are permitted in filenames, here the filename is C:foo.go, and the line is 10
    //line  a:100 :10     blanks are permitted in filenames, here the filename is " a:100 " (excluding quotes)
    /*line :10:20*/x      the position of x is in the current file with line number 10 and column number 20
    /*line foo: 10 */     this comment is recognized as invalid line directive (extra blanks around line number)

## 总结

因阅读源码时看见而产生好奇，通过阅读文档了解到编译指令确实可以提供一些“黑科技”，虽然大部分时候我们都用不到 Go 编译指令，但多了解一些源码和运行机制总不会吃亏的。

参考文档：

 * [Command compile](https://golang.org/cmd/compile/)
 * [简单围观一下有趣的 //go: 指令](https://cloud.tencent.com/developer/article/1422358)
 * [go:nosplit 究竟是个啥？有啥用？](https://maiyang.me/post/2020-07-21-go-nosplit/)
 * [自举](https://en.wikipedia.org/wiki/Bootstrapping_/(compilers/))
 * [[语言思考]编程语言自举的意义](https://www.louyaning.cn/article/csdn-%E7%BC%96%E8%BE%91?id=6475)
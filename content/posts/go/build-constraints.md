---
title: "Go条件编译"
slug: /go/build-constraints
description: Go条件编译规则与应用
date: 2020-11-13T18:39:55+08:00
type: posts
draft: false
categories:
  - go
tags:
  - go
series:
  -
---

Go是支持条件编译，可能很多人都不知道。Go通过在行注释的前面编写如下代码来实现条件编译。

```go
// +build
```

条件编译的指令可能出现在任何源代码中，不止是*.go文件，可能是go汇编文件。无论是何种源文件，条件编译指令一定都出现在文件的顶部，并且在空行或者其他行注释之前。所以条件编译指令也必须在package语句之前。

---

# 条件编译规则

1. 可以将 // +build 后面的内容当成一个表达式。当表达式返回true时，当前文件参与编译，反之不参与编译。

2. 多个片段之间的空格表示它们之间是OR的关系。如下，表示GOOS值是linux或者darwin时，本文件参与编译。
  ```go
  // +build linux darwin
  ```

3. 多个片段之间的,表示它们之间是AND的关系。如下，表示GOOS值是linux且是amd64架构时，本文件参与编译。
  ```go
  // +build linux,amd64
  ```

4. 以!xxx开头的片段表示当tag xxx设置时，当前文件不参与编译。如下，表示GOOS值是linux时，本文件不参与编译。
  ```go
  // +build !linux
  ```

5. 单文件包含多个条件编译指令时，它们是AND的关系。如下，表示GOOS值是linux且是amd64架构时，本文件参与编译。
  ```go
  // +build linux
  // +build amd64
  ```

6. 一些内建的关键字。
    1. `GOOS`的值，目标操作系统，如linux,darwin。
    2. `GOARCH`的值，目标架构，如amd64。
    3. 编译器，`gc` 或者 `gccgo`。
    4. `cgo` 如果cgo支持，编译。
    5. `gox.x` 只在特定go版本进行编译，不支持beta or minor版本号的条件编译。
    6. `go build` 命令的其他tag。

7. 文件名实现条件编译。条件编译支持以下三种格式（`源码文件名去除类型后缀和_test后缀后`）：
    1. `*_GOOS`    GOOS值与文件名中的GOOS一致时参与编译。
    2. `*_GOARCH`    GOARCH值与文件名中的GOARCH一致时参与编译。
    3. `*_GOOS_GOARCH`    GOARCH,GOOS值与文件名中的GOARCH,GOOS一致时参与编译。

    如 `source_windows_amd64.go` 该文件只在`windows`系统的`amd64`架构下进行编译。

# 示例
示例的文件目录:
```sh
$ tree .
$ .
$ ├── etcd.go
$ ├── go.mod
$ ├── main.go
$ └── redis.go
```

`etcd.go` 当tags中出现etcd字符时，不参与编译。
```go
// +build !etcd

package main

fun init() {
  println("etcd init")
}
```

`redis.go` 当tags中出现redis字符时，不参与编译。
```go
// +build !redis

package main

fun init() {
  println("redis redis")
}
```

`main.go`
```go
package main

func main() {
  println("hell world!")
}
```

下面我们来看看效果吧！

1. 直接编译，不执行条件编译
```sh
$ go run .
$ etcd init
$ redis init
$ hell world!
```

可以看到，etcd.go,redis.go,main.go都被编译了。

1. 不编译redis.go文件
```sh
$ go run -tags redis .   # 我们使用 `-tags` 来设置编译条件。
$ etcd init
$ hell world!
```

这时候我们看到，只有etcd.go和main.go被编译了，redis.go中的init方法没有被执行。

3. 不编译etcd.go文件
```sh
$ go run -tags etcd .   # 我们使用 `-tags` 来设置编译条件。
$ redis init
$ hell world!
```

这时候我们看到，只有redis.go和main.go被编译了，main.go中的init方法没有被执行。

4. 不编译etcd.go和redis.go文件
```sh
$ go run -tags etcd,redis .   # 我们使用 `-tags` 来设置编译条件。
$ hell world!
```

这时候我们看到，只有main.go文件中的main函数被执行了，其他文件中的init方法均没哟被执行。

# 总结

在go的源代码中条件编译使用的非常广泛。比如某些功能在不同操作系统的实现不一样，这时候我们就需要针对不同操作系统分别编写代码，但这些代码都在一个目录中，如果没有条件编译将无法编译成功。又或者我们的配置信息可能来自Redis,Etcd,ZooKeeper等不同的配置源，但在运行时我们只用到Etcd，这时候我们可以对代码进行拆分并编写条件编译指令，在编译时只编译Etcd数据源的代码以减小不必要的依赖。

有些靠编写代码没法控制事情，通过条件编译也许可以帮助你，总之掌握条件编译可以帮助我们更好得完成开发工作，甚至实现一些普通程序员无法理解的“黑科技”。

更多信息请查看官方介绍[Build Constraints](https://golang.org/cmd/g/o#hdr-Build_constraints)。
---
title: "Go项目Gitlab CICD提速指南"
slug: /go/cicd
description: Go project gitlab cicd提速指南
date: 2021-01-16T16:57:19+08:00
type: posts
draft: false
toc: true
featured: true
categories:
  - go
  - cicd
tags:
  - go
  - cicd
  - gilab
  - GOMODCACHE
series:
  -
---

## 背景

我司使用GitLab作为代码仓库，Go项目在CICD过程中需要下载依赖，但大部分情况下依赖并未发生变化，重复下载是无用且非常耗时的操作，严重拖慢了CICD的效率。这对于任何一个追求效率的团队来说都是无法接受的。

之前也了解到一些go依赖缓存的解决方案，但不是特别优雅。从 [`Go 1.15 Release Notes`](https://golang.org/doc/go1.15#tools) 中看到，该版本新增了 `GOMODCACHE` 环境变量的支持，官方说明如下：

    The location of the module cache may now be set with the GOMODCACHE environment variable.
    The default value of GOMODCACHE is GOPATH[0]/pkg/mod, the location of the module cache before this change.

    A workaround is now available for Windows "Access is denied" errors in go commands that access the
    module cache, caused by external programs concurrently scanning the file system (see issue #36568).
    The workaround is not enabled by default because it is not safe to use when Go versions lower than 1.14.2
    and 1.13.10 are running concurrently with the same module cache.
    It can be enabled by explicitly setting the environment variable GODEBUG=modcacheunzipinplace=1.

大概意思就是我们可以通过该环境变量来指定读写依赖的位置。通过这段介绍，我觉得这就是我想要的“完美方案”。

## 开工

说干就干，让我们来测试一下这个新特性。

首先，我们需要设置 `GOMODCACHE` 环境变量。为什么要使用 `$(pwd)` 作为前缀呢？因为 `go1.15` 中不支持使用相对目录作为cache的目录（详情见该[Issue](https://github.com/golang/go/issues/43715)），所以我们使用源代码目录作为缓存的父目录。

    go env -w GOMODCACHE=$(pwd)/.mod_cache/ GOPROXY=https://goproxy.cn,direct`

然后，我开始下来依赖CICD环境。

    go mod tidy

再然后，开始编译可执行文件。这里我编译的是Linux 64位的可执行文件，如果你运行在其他系统中，请按需调整。

    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o server .

最后也是最重要的，告诉GitLab创建和使用缓存的规则。这里我的 cache key 使用 go.mod 文件的md5值，cache path 为 `.mod_cache/` 目录。

    cache:
      key: $(md5 -q go.mod)
      paths:
        - .mod_cache/

让我对GitLab cache的使用过程稍作解释：

{{< mermaid >}}
graph TD;
    A(启动GitLab runner)-->B(Pull指定的镜像);
    B(拉取代码)-->C{ 名为CacheKey的缓存是否存在?};
    C-->|Yes| D[解压缓存];
    C-->|No| E[下载依赖];
    E-->F[编译];
    D-->F[编译];
    F-->G[创建名为CacheKey的缓存];
    G-->H[结束];
{{< /mermaid >}}

最后`build`阶段的完整配置如下：
```yaml
build:
    stage: build
    image: golang:1.15.6
    script:
        - go env -w GOMODCACHE=$(pwd)/.mod_cache/ GOPROXY=https://goproxy.cn,direct
        - go mod tidy
        - CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o server .
    cache:
      key: $(md5 -q go.mod)
      paths:
        - .mod_cache/
    artifacts:
        paths:
            - server
    tags:
        - dind
```

## 收工

让我们来对比一下构建过程的耗时吧。

使用缓存前：

    Duration: 2 minutes 26 seconds
    Timeout: 1h (from project)

    Runner: gitlab dind runner (#167)
    Tags: dind

使用缓存后：

    Duration: 52 seconds
    Timeout: 1h (from project)

    Runner: gitlab dind runner (#167)
    Tags: dind

对比一下使用缓存前后，*构建时间由2分26秒缩减为52秒，大约缩减为原来的35%*，提升明显。我的runner是虚拟机，普通磁盘，如果使用物理机+SSD，应该还可以缩短不少时间。

Go还很年轻，仍然存在很多可优化的地方，我们需要经常关注最新的变化，以便构建更高性能、更可靠，更安全的服务。

---
title: "Go设计模式之Singleton"
slug: /go-patterns/singleton
description: 设计模式
date: 2020-09-30T22:40:58+08:00
type: posts
draft: false
categories:
  - go
tags:
  - go
  - 设计模式
series:
  - Go设计模式
---

# Singleton - 单例模式

保证一个类仅有一个实例，并提供一个访问它的全局访问点。

# 实现

## 饿汉式
饿汉式单例是指在方法调用前，实例就已经创建好了。

按照**用法**使用，可以看到控制台输出10次单例的内存地址是一样的。

```go
package main

import (
	"fmt"
	"sync"
	"time"
)

type (
	server struct {
		port int
	}
)

var (
	instance = &server{}
)

func getServerSingleton() *server {
	return instance
}

/*
server ptr: 0x1182ec0
server ptr: 0x1182ec0
server ptr: 0x1182ec0
server ptr: 0x1182ec0
server ptr: 0x1182ec0
server ptr: 0x1182ec0
server ptr: 0x1182ec0
server ptr: 0x1182ec0
server ptr: 0x1182ec0
server ptr: 0x1182ec0
*/
```

## 懒汉式 - 非Goroutine安全

懒汉式单例是指在方法调用获取实例时才创建实例，因为相对饿汉式显得“不急迫”，所以被叫做“懒汉模式”。

按照**用法**使用，可以看到控制台输出10次单例的内存地址并不完全一样。

一共有以下3个指针：
* 0xc0000c4000
* 0xc0000ca000
* 0xc0000c2000

可见此懒汉模式不支持在实例未初始化时高并发调用。

```go
package main

type (
	server struct {
		port int
	}
)

var (
	instance *server
)

func getServerSingleton() *server {
	if instance == nil {
		instance = &server{}
	}

	return instance
}

/*
server ptr: 0xc0000c4000
server ptr: 0xc0000ca000
server ptr: 0xc0000c4000
server ptr: 0xc0000c2000
server ptr: 0xc0000c2000
server ptr: 0xc0000ca000
server ptr: 0xc0000ca000
server ptr: 0xc0000ca000
server ptr: 0xc0000ca000
server ptr: 0xc0000ca000
*/
```

## 懒汉式 - Goroutine安全

我们可以利用golang sync包提供的Once结构体来解决Goroutine安全问题。Once提供了在应用程序生命周期中仅会被调用一次的解决方案。我们将实例的生成过程使用Once保护起来，那么即可以做到单例。

```go
package main

import (
	"sync"
)

type (
	server struct{}
)

var (
	instance *server
	once     sync.Once
)

func getServerSingleton() *server {
	once.Do(func() {
		instance = &server{}
	})

	return instance
}

/*
server ptr: 0x1182f88
server ptr: 0x1182f88
server ptr: 0x1182f88
server ptr: 0x1182f88
server ptr: 0x1182f88
server ptr: 0x1182f88
server ptr: 0x1182f88
server ptr: 0x1182f88
server ptr: 0x1182f88
server ptr: 0x1182f88
*/
```

# 用法

模拟10个并发请求获取单例。

```go
func main() {
	wg := sync.WaitGroup{}

	for index := 0; index < 10; index++ {
		wg.Add(1)

		go func() {
			time.Sleep(time.Millisecond * 100)

			server := getServerSingleton()
			fmt.Printf("server ptr: %p \n", server)

			wg.Done()
		}()
	}

	wg.Wait()
}
```
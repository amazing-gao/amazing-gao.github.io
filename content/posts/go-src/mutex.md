---
title: "Go源码解析之mutex"
slug: /go-src/sync/mutex
description: null
date: 2020-11-16T21:20:54+08:00
type: posts
draft: false
toc: true
featured: true
categories:
  - go
tags:
  - go
  - sync
  - mutex
  - 互斥锁
series:
  - Go源码解析
---

## 概要

今天我们来看看Go中的互斥锁 `sync/mutex`。

我们借用互斥锁在维基百科上的定义：<u>[互斥锁（英语：Mutual exclusion，缩写 Mutex）](https://zh.wikipedia.org/wiki/%E4%BA%92%E6%96%A5%E9%94%81)是一种用于多线程编程中，防止两条线程同时对同一公共资源（比如全局变量）进行读写的机制。该目的通过将代码切片成一个一个的临界区域（critical section）达成。临界区域指的是一块对公共资源进行访问的代码，并非一种机制或是算法。一个程序、进程、线程可以拥有多个临界区域，但是并不一定会应用互斥锁。</u>

在Go中我们无法直接操作线程，使用 `go` 关键字启动的是goroutine，但goroutine的背后还是操作系统的线程，所以在此我们讨论的是多个goroutine之间的互斥锁。



## 用法

互斥锁的使用非常简单，初始化一个mutex，它的默认状态是**unlock**的。

`Lock` 方法表示这是临界区的开始，后续代码在访问公共资源时是受控的。调用该方法时，如果互斥锁已经是加锁的状态，goroutine将一直阻塞，直到锁释放。

`Unlock` 方法表示这是临界区的结束，之前的代码在访问公共资源时是受控的，但之后的将不再受控。调用该方法时，如果互斥锁是未加锁的状态，将会产生一个runtime error。

### 举个反例

```go
package main

import (
	"fmt"
	"runtime"
	"sync"
	"time"
)

var (
	number int
	mutex  sync.Mutex
)

func main() {
	runtime.GOMAXPROCS(10)

	for i := 0; i < 1000; i++ {
		go Add()
	}

	time.Sleep(time.Second)
	fmt.Println(number)
}

func Add() {
	number++
}
```

源代码可以在 [Playground](https://play.golang.org/p/8HDmJB50wS6) 查看。

我们预先声明了两个变量： `number` 是全局变量，即公共资源；`mutex` 即互斥锁。

然后在main函数中的 [runtime.GOMAXPROCS(10)](https://golang.org/pkg/runtime/#GOMAXPROCS) 即Line#16，十分重要。它表示Go将启动10个线程来处理任务，这样才能模拟多线程的情况。如果你是单核单线程的CPU或者设置了`runtime.GOMAXPROCS(1)`，本例子将不适用，因为单线程环境不存在并发访问。

之后我们启动1000个goroutine对全局变量 `number` 进行累加。

最后等待1s（1000次累加肯定不会超过1s，这里仅做demo，真实环境不要这么玩），并打印结果。

将该程序执行多次，我们会发现打印的结果并不总是1000，有时是979，有时是941等等结果。

这就是因为 `number` 是公共资源，多个goroutine在对其进行累加时可能是多线程并发进行的，累加时有些线程获取到的是`旧值`，累加完成之后又将旧值的计算结果赋值给了 `number`，导致部分并发计算的结果被覆盖了。

### 正确写法

```go
package main

import (
	"fmt"
	"runtime"
	"sync"
	"time"
)

var (
	number int
	mutex  sync.Mutex
)

func main() {
	runtime.GOMAXPROCS(10)

	for i := 0; i < 1000; i++ {
		go Add()
	}

	time.Sleep(time.Second)
	fmt.Println(number)
}

func Add() {
	mutex.Lock()
	defer mutex.Unlock()
	number++
}
```

源代码可以在 [Playground](https://play.golang.org/p/R6RLYFNPfj8) 查看。

这段代码与之前的区别就是`Line#27`,`Line#28`，我们对累加操作进行了保护，声明这里是临界区，禁止多个goroutine并发访问。

无论我们执行多少次代码，发现结果始终都是1000。这是如何实现的呢？请继续往下看。



## 一探究竟

打开源代码，[`Mutex`](https://github.com/golang/go/blob/master/src/sync/mutex.go#L25-L28)的定义非常简单，但没有注释，我们并不知道state与sema分别是做什么用的。

```go
type Mutex struct {
	state int32
	sema  uint32
}
```

那我们就看看[`Lock`](https://github.com/golang/go/blob/master/src/sync/mutex.go#L72-L82)方法吧。

```go
func (m *Mutex) Lock() {
	// Fast path: grab unlocked mutex.
	if atomic.CompareAndSwapInt32(&m.state, 0, mutexLocked) {
		if race.Enabled {
			race.Acquire(unsafe.Pointer(m))
		}
		return
	}
	// Slow path (outlined so that the fast path can be inlined)
	m.lockSlow()
}
```

 `Line#3` 是一个`CompareAndSwapInt32` 。这个方法我们之前聊过（请查看[Go源码解析之atomic](https://amazingao.com/posts/2020/11/go-src/sync/atomic/)），将 `m.state` 与 `0` 比较，如果相等那么 `mutexLocked` 的值将赋值给 `m.state` 并返回 true。也就是说这里就可以初步判断锁的状态。 `mutexLocked` 是在代码的开头部分声明的常量。`通过此我们可以推断出来state表示互斥锁的状态：0 表示未锁；1 表示已锁(mutexLocked的值)`。

`Line#4-6` 是开启race检测时的一些逻辑，我们暂时忽略。

`Line#10` 我们看到调用了自身的方法 `lockSlow()` ，让我们看看这个方法。



[slowLock](https://github.com/golang/go/blob/master/src/sync/mutex.go#L84-L171) 这段代码稍微长一些。

```go
func (m *Mutex) lockSlow() {
	var waitStartTime int64
	starving := false
	awoke := false
	iter := 0
	old := m.state
	for {
		// Don't spin in starvation mode, ownership is handed off to waiters
		// so we won't be able to acquire the mutex anyway.
		if old&(mutexLocked|mutexStarving) == mutexLocked && runtime_canSpin(iter) {
			// Active spinning makes sense.
			// Try to set mutexWoken flag to inform Unlock
			// to not wake other blocked goroutines.
			if !awoke && old&mutexWoken == 0 && old>>mutexWaiterShift != 0 &&
				atomic.CompareAndSwapInt32(&m.state, old, old|mutexWoken) {
				awoke = true
			}
			runtime_doSpin()
			iter++
			old = m.state
			continue
		}
		new := old
		// Don't try to acquire starving mutex, new arriving goroutines must queue.
		if old&mutexStarving == 0 {
			new |= mutexLocked
		}
		if old&(mutexLocked|mutexStarving) != 0 {
			new += 1 << mutexWaiterShift
		}
		// The current goroutine switches mutex to starvation mode.
		// But if the mutex is currently unlocked, don't do the switch.
		// Unlock expects that starving mutex has waiters, which will not
		// be true in this case.
		if starving && old&mutexLocked != 0 {
			new |= mutexStarving
		}
		if awoke {
			// The goroutine has been woken from sleep,
			// so we need to reset the flag in either case.
			if new&mutexWoken == 0 {
				throw("sync: inconsistent mutex state")
			}
			new &^= mutexWoken
		}
		if atomic.CompareAndSwapInt32(&m.state, old, new) {
			if old&(mutexLocked|mutexStarving) == 0 {
				break // locked the mutex with CAS
			}
			// If we were already waiting before, queue at the front of the queue.
			queueLifo := waitStartTime != 0
			if waitStartTime == 0 {
				waitStartTime = runtime_nanotime()
			}
			runtime_SemacquireMutex(&m.sema, queueLifo, 1)
			starving = starving || runtime_nanotime()-waitStartTime > starvationThresholdNs
			old = m.state
			if old&mutexStarving != 0 {
				// If this goroutine was woken and mutex is in starvation mode,
				// ownership was handed off to us but mutex is in somewhat
				// inconsistent state: mutexLocked is not set and we are still
				// accounted as waiter. Fix that.
				if old&(mutexLocked|mutexWoken) != 0 || old>>mutexWaiterShift == 0 {
					throw("sync: inconsistent mutex state")
				}
				delta := int32(mutexLocked - 1<<mutexWaiterShift)
				if !starving || old>>mutexWaiterShift == 1 {
					// Exit starvation mode.
					// Critical to do it here and consider wait time.
					// Starvation mode is so inefficient, that two goroutines
					// can go lock-step infinitely once they switch mutex
					// to starvation mode.
					delta -= mutexStarving
				}
				atomic.AddInt32(&m.state, delta)
				break
			}
			awoke = true
			iter = 0
		} else {
			old = m.state
		}
	}

	if race.Enabled {
		race.Acquire(unsafe.Pointer(m))
	}
}
```

TODO
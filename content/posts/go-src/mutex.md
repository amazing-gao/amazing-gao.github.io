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

今天我们来看看Go中的互斥锁 `sync/mutex`。本文基于`go1.15.5` 进行分析。

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

无论我们执行多少次代码，发现结果始终都是1000。这在Go中是如何实现的呢？请继续往下看。



## 一探究竟

打开源代码，我们看到一段关于 [Mutex fairness](https://github.com/golang/go/blob/go1.15.5/src/sync/mutex.go#L42-L65) 的注释。

```go
	// Mutex fairness.
	//
	// Mutex can be in 2 modes of operations: normal and starvation.
	// In normal mode waiters are queued in FIFO order, but a woken up waiter
	// does not own the mutex and competes with new arriving goroutines over
	// the ownership. New arriving goroutines have an advantage -- they are
	// already running on CPU and there can be lots of them, so a woken up
	// waiter has good chances of losing. In such case it is queued at front
	// of the wait queue. If a waiter fails to acquire the mutex for more than 1ms,
	// it switches mutex to the starvation mode.
	//
	// In starvation mode ownership of the mutex is directly handed off from
	// the unlocking goroutine to the waiter at the front of the queue.
	// New arriving goroutines don't try to acquire the mutex even if it appears
	// to be unlocked, and don't try to spin. Instead they queue themselves at
	// the tail of the wait queue.
	//
	// If a waiter receives ownership of the mutex and sees that either
	// (1) it is the last waiter in the queue, or (2) it waited for less than 1 ms,
	// it switches mutex back to normal operation mode.
	//
	// Normal mode has considerably better performance as a goroutine can acquire
	// a mutex several times in a row even if there are blocked waiters.
	// Starvation mode is important to prevent pathological cases of tail latency.
```

大致意思是：

1. `Mutex`是一把`公平锁（Mutex fairness）`。
2. `Mutex`有两种模式：`正常模式`和`饥饿模式`
	1. `正常模式`：在正常模式，`waiters`是按照先进先出的顺序进行排队，但是一个被唤醒的`waiter`不会直接占有锁，而是需要和其他新请求锁的goroutines一起竞争锁的所有权。新请求锁的goroutines有一个优势 --- 它们已经运行在CPU中并且可能数量不少，所以一个被唤醒的waiter有很大机会会竞争输了。在这种情况它将被排在等待队列的前面。如果`waiter`超过`1ms`没有成功获取锁，锁将切换为`饥饿模式`。
	2. `饥饿模式`：在饥饿模式，锁的所有权直接从一个刚解锁的goroutine手中直接传递到等待队列最前面的`waiter`手中。新请求锁的goroutines不会尝试获取锁即使看起来是未锁的状态，也不会尝试自旋。取而代之的是，它们将排在等待队列的队尾。
3. 如果`waiter`获取到锁的所有权时，发现自己是队列中最后一个`waiter`或者自己等待时间小于`1ms`，那么锁将切换回`正常模式`。
4. `正常模式`拥有非常好的性能表现，因为即使存在阻塞的`waiter`，一个goroutine也能够多次获取锁。
5. `饥饿模式`对于预防极端的长尾时延（tail latency）非常重要。

PS：这里`waiter`和`waiters`表示等待的goroutines。

作者详细的描述了互斥锁的设计思路与运行过程，这对于我们理解代码至关重要。



在我们开始阅读代码之前，这里有几个const值非常重要，我们先介绍一下。

```go
const (
	mutexLocked = 1 << iota // mutex is locked
	mutexWoken
	mutexStarving
	mutexWaiterShift = iota
	starvationThresholdNs = 1e6
)
```

`mutexLocked` 值是`1`，代表已锁状态。

`mutexWoken` 值是`2`，代表唤醒状态。

`mutexStarving` 值是4，代表饥饿状态。

`mutexWaiterShift` 值是3，代表waiter计数器开始的位移量。

`starvationThresholdNs` 代表`1ms`。

让我们继续，[`Mutex`](https://github.com/golang/go/blob/go1.15.5/src/sync/mutex.go#L25-L28)的定义非常简单，但没有注释，我们并不知道state与sema分别是做什么用的。

```go
type Mutex struct {
	state int32
	sema  uint32
}
```



### Lock

那我们就带着问题看看[`Lock`](https://github.com/golang/go/blob/go1.15.5/src/sync/mutex.go#L72-L82)方法吧。

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

 `Line#3` 是一个`CompareAndSwapInt32` 。这个方法我们之前聊过（请查看[Go源码解析之atomic](https://amazingao.com/posts/2020/11/go-src/sync/atomic/)），将 `m.state` 与 `0` 比较，如果相等那么 `mutexLocked` 的值将赋值给 `m.state` 并返回 true。也就是说这里就可以初步判断锁的状态。 `mutexLocked` 是在代码的开头部分声明的常量。`通过变量名与此我们可以推断出来state可以表示互斥锁的状态`。

`Line#4-6` 是开启race检测时的一些逻辑，我们暂时忽略，下次专门写一篇文章介绍。

`Line#10` 我们看到调用了自身的方法 `lockSlow()` ，让我们看看这个方法。



[slowLock](https://github.com/golang/go/blob/go1.15.5/src/sync/mutex.go#L84-L171) 这段代码稍微长一些，我们直接在代码里通过注释进行解析。

```go
func (m *Mutex) lockSlow() {
	var waitStartTime int64 // 当前goroutine的等待时间
	starving := false       // 当前goroutine是否饥饿状态
	awoke := false          // 当前goroutine是否唤醒状态
	iter := 0               // 当前goroutine自旋次数
	old := m.state          // copy锁的状态为历史状态

	for {
		// Don't spin in starvation mode, ownership is handed off to waiters
		// so we won't be able to acquire the mutex anyway.
		// 在饥饿模式不进行自旋，锁的所有权会自己移交给waiters。
		// 所以无论如何我们都无法获取锁。

		// 当锁是locked状态并且当前goroutine可以自旋时，开始自旋。
		// 当锁是starving状态，就直接false，不自旋。
		if old&(mutexLocked|mutexStarving) == mutexLocked && runtime_canSpin(iter) {
			// Active spinning makes sense.
			// Try to set mutexWoken flag to inform Unlock
			// to not wake other blocked goroutines.
			// 触发自旋是有意义的。
			// 尝试设置woken标志来通知unlock，以便不唤起其他阻塞的goroutines。

			if !awoke && old&mutexWoken == 0 && old>>mutexWaiterShift != 0 &&
				atomic.CompareAndSwapInt32(&m.state, old, old|mutexWoken) {
				// 如果当前goroutine是未唤醒状态，互斥锁也是未唤醒状态，并且互斥锁的waiter数量不等于0，
				// 就比较锁的最新状态（m.state）和历史状态（old），如果未发生改变，将锁的状态更新为woken。
				// 并且设置当前goroutine为awoke状态。
				awoke = true
			}

			// 自旋
           // https://github.com/golang/go/blob/go1.15.5/src/runtime/proc.go#L6055-L6057
            // https://github.com/golang/go/blob/go1.15.5/src/runtime/asm_amd64.s#L574-L580
			runtime_doSpin()

			// 自旋次数递增
			iter++

			// copy锁的状态为历史状态，自旋期间其他goroutine可能修改了state，所以要更新。
			old = m.state

			// 继续尝试自旋
			continue
		}

		new := old // copy锁的历史状态为new状态。

		// Don't try to acquire starving mutex, new arriving goroutines must queue.
		// 饥饿模式时不尝试获取锁，新来的goroutines必须排队。
		// 如果锁的历史状态（old）不是starving状态，将锁的新状态（new）更新为locked状态。
		if old&mutexStarving == 0 {
			new |= mutexLocked
		}

		// 如果锁的历史状态（old）是locked状态或者是starving状态，将锁的waiter数量加1。
		if old&(mutexLocked|mutexStarving) != 0 {
			new += 1 << mutexWaiterShift
		}

		// The current goroutine switches mutex to starvation mode.
		// But if the mutex is currently unlocked, don't do the switch.
		// Unlock expects that starving mutex has waiters, which will not
		// be true in this case.
		// 当前goroutine切换锁为饥饿模式。
		// 当锁是unlocked状态时，不切换为饥饿模式。
		// unlock期望饥饿模式的锁有waiters，但是在本例中不会出现。

		// 如果当前goroutine是starving状态且锁的历史状态（old）是locked状态，将锁的新状态（new）更新为starving状态。
		if starving && old&mutexLocked != 0 {
			new |= mutexStarving
		}



		// 如果当前goroutine是awoke状态
		if awoke {
			// The goroutine has been woken from sleep,
			// so we need to reset the flag in either case.
			// goroutine已经从sleep状态被唤醒。
			// 我们需要重置flag状态。

			if new&mutexWoken == 0 { // 如果锁的新状态（new）不是woken状态，抛异常，状态不一致。
				throw("sync: inconsistent mutex state")
			}

			// &^ 是 bit clear (AND NOT)
			// https://golang.org/ref/spec#Arithmetic_operators
			// 取消锁的新状态（new）的woken状态标志。
			new &^= mutexWoken
		}



		// 比较锁的最新状态（m.state）和历史状态（old），如果未发生改变，那么更新为new。
		if atomic.CompareAndSwapInt32(&m.state, old, new) {
			// 如果cas更新成功，并且锁的历史状态（old）即不是locked也不是starving，那么结束循环，通过CAS加锁成功。
			if old&(mutexLocked|mutexStarving) == 0 {
				break // locked the mutex with CAS
			}

			// If we were already waiting before, queue at the front of the queue.
			// 如果之前已经等待，将排在队列前面。

			// 当前goroutine是否等待过。
			queueLifo := waitStartTime != 0

			// 如果开始等待时间为0，更新为当前时间为开始等待时间。
			if waitStartTime == 0 {
				waitStartTime = runtime_nanotime()
			}

			// 通过信号量获取锁
			// runtime实现代码：https://github.com/golang/go/blob/go1.15.5/src/runtime/sema.go#L69-L72
			// runtime信号量获取：https://github.com/golang/go/blob/go1.15.5/src/runtime/sema.go#L98-L153
			runtime_SemacquireMutex(&m.sema, queueLifo, 1)

			// 如果当前goroutine是starving状态或者等待时间大于1ms，更新当前goroutine为starving状态。
			starving = starving || runtime_nanotime()-waitStartTime > starvationThresholdNs

			// 更新锁的历史状态（old）
			old = m.state

			// 如果锁是饥饿状态，才执行里面的代码。
			if old&mutexStarving != 0 {
				// If this goroutine was woken and mutex is in starvation mode,
				// ownership was handed off to us but mutex is in somewhat
				// inconsistent state: mutexLocked is not set and we are still
				// accounted as waiter. Fix that.
				// 如果当前goroutine是唤醒状态并且锁在饥饿模式，
				// 锁的所有权转移给当前goroutine，但是锁处于不一致的状态中：mutexLocked没有设置
				// 并且我们将任然被认为是waiter。这个状态需要被修复。

				// 如果锁的历史状态（old）是locked或者woken的，或者waiters的数量不为0，触发锁状态异常。
				if old&(mutexLocked|mutexWoken) != 0 || old>>mutexWaiterShift == 0 {
					throw("sync: inconsistent mutex state")
				}

				// 当前goroutine获取锁，waiter数量-1
				delta := int32(mutexLocked - 1<<mutexWaiterShift)

				// 如果当前goroutine不是starving状态或者锁的历史状态（old）的waiter数量是1，delta减去3。
				if !starving || old>>mutexWaiterShift == 1 {
					// Exit starvation mode.
					// Critical to do it here and consider wait time.
					// Starvation mode is so inefficient, that two goroutines
					// can go lock-step infinitely once they switch mutex
					// to starvation mode.
					// 退出饥饿模式
					// 在这里这么做至关重要，还要考虑等待时间。
					// 饥饿模式是非常低效率的，一旦两个goroutine将互斥锁切换为饥饿模式，它们便可以无限锁。

					delta -= mutexStarving
				}

				// 更新锁的状态
				atomic.AddInt32(&m.state, delta)
				break
			}

			// 当前goroutine更新为awoke状态
			awoke = true

			// 当前goroutine自旋次数清零
			iter = 0
		} else {
			// 更新锁的历史状态（old）
			old = m.state
		}
	}

	if race.Enabled {
		race.Acquire(unsafe.Pointer(m))
	}
}
```

主流程并不是很容易理解，建议多阅读几遍。这里一定要弄清楚的是，这个方法会被多个goroutine并发调用，局部变量的状态表示当前goroutine的状态，m.state就是锁的状态。

我们继续深入了解一下主流程中的 [runtime_doSpin](https://github.com/golang/go/blob/go1.15.5/src/runtime/proc.go#L6055-L6057) 方法，可以看到doSpin就是循环执行 `PAUSE` 指令30次。`PAUSE` 指令简单来说就是提升自旋等待循环（spin-wait loop）的性能，还可以省电。

```go
//go:linkname sync_runtime_doSpin sync.runtime_doSpin
//go:nosplit
func sync_runtime_doSpin() {
	procyield(active_spin_cnt)  // 	active_spin_cnt = 30
}
```

[procyield](https://github.com/golang/go/blob/go1.15.5/src/runtime/asm_amd64.s#L574-L580) 汇编代码如下：

```asm
TEXT runtime·procyield(SB),NOSPLIT,$0-0
	MOVL	cycles+0(FP), AX
again:
	PAUSE
	SUBL	$1, AX
	JNZ	again
	RET
```



我们再来看看主流程中的 `runtime_SemacquireMutex` 方法，这是一个信号量操作。关于信号量，以下是go给出的描述：

```go
// Semaphore implementation exposed to Go.
// Intended use is provide a sleep and wakeup
// primitive that can be used in the contended case
// of other synchronization primitives.
// Thus it targets the same goal as Linux's futex,
// but it has much simpler semantics.
//
// That is, don't think of these as semaphores.
// Think of them as a way to implement sleep and wakeup
// such that every sleep is paired with a single wakeup,
// even if, due to races, the wakeup happens before the sleep.
//
// See Mullender and Cox, ``Semaphores in Plan 9,''
// https://swtch.com/semaphore.pdf
```

大意就是，Go的信号量与其他同步原语中的信号量不同，在Go中应该把信号量比作sleep与wakeup的机制。

[runtime_SemacquireMutex](https://github.com/golang/go/blob/go1.15.5/src/runtime/sema.go#L69-L71)

```go
//go:linkname sync_runtime_SemacquireMutex sync.runtime_SemacquireMutex
func sync_runtime_SemacquireMutex(addr *uint32, lifo bool, skipframes int) {
	semacquire1(addr, lifo, semaBlockProfile|semaMutexProfile, skipframes)
}
```

[semacquire1](https://github.com/golang/go/blob/go1.15.5/src/runtime/sema.go#L98-L153)

```go
func semacquire1(addr *uint32, lifo bool, profile semaProfileFlags, skipframes int) {
	gp := getg()
	if gp != gp.m.curg {
		throw("semacquire not on the G stack")
	}

	// Easy case.
	if cansemacquire(addr) {
		return
	}

	// Harder case:
	//	increment waiter count
	//	try cansemacquire one more time, return if succeeded
	//	enqueue itself as a waiter
	//	sleep
	//	(waiter descriptor is dequeued by signaler)
	s := acquireSudog()
	root := semroot(addr)
	t0 := int64(0)
	s.releasetime = 0
	s.acquiretime = 0
	s.ticket = 0
	if profile&semaBlockProfile != 0 && blockprofilerate > 0 {
		t0 = cputicks()
		s.releasetime = -1
	}
	if profile&semaMutexProfile != 0 && mutexprofilerate > 0 {
		if t0 == 0 {
			t0 = cputicks()
		}
		s.acquiretime = t0
	}
	for {
		lockWithRank(&root.lock, lockRankRoot)
		// Add ourselves to nwait to disable "easy case" in semrelease.
		atomic.Xadd(&root.nwait, 1)
		// Check cansemacquire to avoid missed wakeup.
		if cansemacquire(addr) {
			atomic.Xadd(&root.nwait, -1)
			unlock(&root.lock)
			break
		}
		// Any semrelease after the cansemacquire knows we're waiting
		// (we set nwait above), so go to sleep.
		root.queue(addr, s, lifo)
		goparkunlock(&root.lock, waitReasonSemacquire, traceEvGoBlockSync, 4+skipframes)
		if s.ticket != 0 || cansemacquire(addr) {
			break
		}
	}
	if s.releasetime > 0 {
		blockevent(s.releasetime-t0, 3+skipframes)
	}
	releaseSudog(s)
}
```

这里信号量获取操作简单来说就是把自己丢进等待队列，然后等待被唤起。

我们继续看看 `Unlock` 是怎么实现的。

### Unlock

[Unlock](https://github.com/golang/go/blob/go1.15.5/src/sync/mutex.go#L173-L192) 的源代码相较于Lock就简单很多，首先看到 `Fast path`，就是去除锁的标志位，看是否已解锁。

```go
// Unlock unlocks m.
// It is a run-time error if m is not locked on entry to Unlock.
//
// A locked Mutex is not associated with a particular goroutine.
// It is allowed for one goroutine to lock a Mutex and then
// arrange for another goroutine to unlock it.
func (m *Mutex) Unlock() {
	if race.Enabled {
		_ = m.state
		race.Release(unsafe.Pointer(m))
	}

	// Fast path: drop lock bit.
    // 如果waiter数量为0，三个标志位去除locked后也为0，那么可以解锁了。
	new := atomic.AddInt32(&m.state, -mutexLocked)
	if new != 0 {
		// Outlined slow path to allow inlining the fast path.
		// To hide unlockSlow during tracing we skip one extra frame when tracing GoUnblock.
		m.unlockSlow(new)
	}
}
```

我们继续看看 [unlockSlow](https://github.com/golang/go/blob/go1.15.5/src/sync/mutex.go#L194-L226) 的源代码。

```go
func (m *Mutex) unlockSlow(new int32) {
	if (new+mutexLocked)&mutexLocked == 0 {
		throw("sync: unlock of unlocked mutex")
	}

	if new&mutexStarving == 0 {
		// 如果不是饥饿模式
		old := new
		for {
			// If there are no waiters or a goroutine has already
			// been woken or grabbed the lock, no need to wake anyone.
			// In starvation mode ownership is directly handed off from unlocking
			// goroutine to the next waiter. We are not part of this chain,
			// since we did not observe mutexStarving when we unlocked the mutex above.
			// So get off the way.
			// 如果waiter数量为0，锁的三个标志位任一非0，直接返回
			if old>>mutexWaiterShift == 0 || old&(mutexLocked|mutexWoken|mutexStarving) != 0 {
				return
			}

			// Grab the right to wake someone.
			// 尝试将锁更新为woken状态，如果成功了，就通过信号量去唤醒goroutine。
			new = (old - 1<<mutexWaiterShift) | mutexWoken
			if atomic.CompareAndSwapInt32(&m.state, old, new) {
				runtime_Semrelease(&m.sema, false, 1)
				return
			}
			old = m.state
		}
	} else {
		// Starving mode: handoff mutex ownership to the next waiter, and yield
		// our time slice so that the next waiter can start to run immediately.
		// Note: mutexLocked is not set, the waiter will set it after wakeup.
		// But mutex is still considered locked if mutexStarving is set,
		// so new coming goroutines won't acquire it.
		// 饥饿模式直接手把手交接锁的控制权
		runtime_Semrelease(&m.sema, true, 1)
	}
}
```

到这里我们已经大概清楚 `Mutex` 加锁与解锁的过程。

在这个过程中，经过分析和推理，我们可以断定：

sema是信号量状态标志。

state被被切分为4块，每块分别有不同的作用，如下表：

| 31-3位       | 2位          | 1位       | 0位        |
| ------------ | ------------ | --------- | ---------- |
| Waiter的数量 | Starving状态 | Woken状态 | Locked状态 |



## 总结

通过源码分析，我们了解到Mutex的内部实现非常的巧妙。Go的作者为了保证性能与公平思考的非常多，但是这并不是银弹，在实际开发中我们不能肆无忌惮的使用互斥锁，尤其是一些对性能要求较高的场景和业务。在设计程序时，我们应当使用恰当的锁（比如读写锁），并尽量降低锁的颗粒度避免频繁互斥，或者使用一些无锁的方案。

## 参考文档

1. [一份详细注释的go Mutex源码](http://cbsheng.github.io/posts/%E4%B8%80%E4%BB%BD%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A%E7%9A%84go-mutex%E6%BA%90%E7%A0%81/)
2. [源码剖析 golang 中 sync.Mutex](https://purewhite.io/2019/03/28/golang-mutex-source/)
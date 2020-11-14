---
title: "Go源码解析之atomic"
slug: /go-src/sync/atomic
description: null
date: 2020-11-08T20:16:35+08:00
type: posts
draft: false
toc: true
categories:
  - go
tags:
  - go
  - sync
  - atomic
series:
  - Go源码解析
---

今天我们来聊聊go的**atomic** pkg，**atomic**是go并发编程中最为基础的库。如果说它是go并发编程的基石一点也不为过，像标准库中大家使用率非常高的**Mutex**, **RWMutex**,**WaitGroup**,**Once**等的实现都依赖于**atomic**。

## Atomic简介

**atomic**提供一系列用于实现同步功能的、底层的，原子的方法：

1. **AddT** 系列将增量增加到源值上，并返回新值。
2. **CompareAndSwapT** 系列比较两个变量的值，并进行交换。
3. **SwapT**系列交换值，并返回旧值。
4. **LoadT** 系列获取值。
5. **StoreT** 系列更新值。
6. **Value** 存储器，支持Load,Store。

这些方法是原子操作，不会被CPU中断，也就说在多个goroutine之间访问是安全的。

比如**CompareAndSwapT**方法，其实它包含多个步骤，在CPU执行时也是多个命令完成这个功能。

```go
if *addr == old {
	*addr = new
	return true
}
return false
```

那么go是如何让这些方法变成了原子操作呢？我们接着往下看。

## 刨根问底

为了搞清楚**atomic**到底是如何工作的，我们以**CompareAndSwapInt32**为例来分析。我打开了[atomic](https://github.com/golang/go/tree/master/src/sync/atomic)的源代码。

```sh
asm.s
atomic_test.go
doc.go
example_test.go
race.s
value.go
value_test.go
```

包内的文件数并不多，打开第一个**asm.s**，我们就看到非常重要的内容。

这是一个go汇编文件，我摘取了部分重要的内容。

```asm
// +build !race

#include "textflag.h"

TEXT ·SwapInt32(SB),NOSPLIT,$0
	JMP	runtime∕internal∕atomic·Xchg(SB)

// ...略去...

TEXT ·CompareAndSwapInt32(SB),NOSPLIT,$0
	JMP	runtime∕internal∕atomic·Cas(SB)

// ...略去...

TEXT ·AddInt32(SB),NOSPLIT,$0
	JMP	runtime∕internal∕atomic·Xadd(SB)

// ...略去...

TEXT ·LoadInt32(SB),NOSPLIT,$0
	JMP	runtime∕internal∕atomic·Load(SB)

// ...略去...

TEXT ·StoreInt32(SB),NOSPLIT,$0
	JMP	runtime∕internal∕atomic·Store(SB)
```

`// +build !race` 这是go的条件编译，表示race时不编译，不是本文重点，欲知更多请查看[Go build constraints](https://golang.org/cmd/go/#hdr-Build_constraints)。`#include "textflag.h"` 引用头文件，定义了一些宏。

下面来到我们的重点 `TEXT ·CompareAndSwapInt32(SB),NOSPLIT,$0` 定义了CompareAndSwapInt32函数，可以看到它并没有什么逻辑，直接跳转去了`runtime∕internal∕atomic·Cas`。那么我们就跟过去。

我们查看amd64版本代码[stubs.go](https://github.com/golang/go/blob/master/src/runtime/internal/atomic/stubs.go#L12)，看到了函数的声明**func Cas(ptr *uint32, old, new uint32) bool**，但是并没有函数体。Go还可以这么玩？函数体去哪里了？

经过一番侦查，在[asm_amd64.s](https://github.com/golang/go/blob/master/src/runtime/internal/atomic/asm_amd64.s#L17)中发现了汇编实现的函数体。

```asm
// bool Cas(int32 *val, int32 old, int32 new)
// Atomically:
//	if(*val == old){
//		*val = new;
//		return 1;
//	} else
//		return 0;
TEXT runtime∕internal∕atomic·Cas(SB),NOSPLIT,$0-17
	MOVQ	ptr+0(FP), BX
	MOVL	old+8(FP), AX
	MOVL	new+12(FP), CX
	LOCK
	CMPXCHGL	CX, 0(BX)
	SETEQ	ret+16(FP)
	RET
```

第一行MOVQ ptr到BX寄存器。**FP** 是go汇编定义的伪寄存器，伪FP寄存器对应的是函数的帧指针，一般用来访问函数的参数和返回值。Go汇编是基于[plan9](https://9p.io/sys/doc/asm.html)的，MOV的方向和我们常规学习到的相反。

第二行MOVL old值到AX寄存器。

第三行MOVL new值到CX寄存器。

第四行**LOCK**，这个命令非常陌生。经过一番资料查询了解到[Intel® 64 and IA-32 Architectures Software Developer’s Manual](https://software.intel.com/sites/default/files/managed/39/c5/325462-sdm-vol-1-2abcd-3abcd.pdf)，LOCK能将后续的指令变成原子操作，那么后续的**CMPXCHGL**也将被原子化。

第五行CMPXCHGL	CX, 0(BX)，将BX的值(ptr)与CX的值(new)比较。如果相等，CX更新到ptr，否者BX更新到AX。

第六行SETEQ	ret+16(FP)，如果ZF标志位为0，设置1到返回值(FP偏移16位)，否者设置0。

第七行RET 函数返回。



    这里最重要的是**LOCK**与**CMPXCHGL**两个命令，两条命令组合完成了Cas操作。
    这是CPU支持的原子操作。关于CPU的LOCK指令后续我们单独介绍。



atomic中其他方法实现原子操作的方案基本与此一致，在此就不赘述了，有兴趣的童鞋可以自己研究一下。


## 参考文档

1. [探索 Golang 一致性原语](https://wweir.cc/post/%E6%8E%A2%E7%B4%A2-golang-%E4%B8%80%E8%87%B4%E6%80%A7%E5%8E%9F%E8%AF%AD/)
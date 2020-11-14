---
title: "Go设计模式之Factory"
slug: factory
description: null
date: 2020-10-14T20:30:39+08:00
type: posts
draft: false
toc: true
categories:
  - go
tags:
  - go
  - 设计模式
series:
  - Go设计模式
---

## Factory - 工厂模式

工厂模式在Go中使用的非常广泛，比如常用于数据的读写模块。假设我们需要从某种介质中读取数据，并将更新后的结果保存到该介质中。考虑到以后可能更换为其他类型的介质，为了避免日后更换介质而大面积变更代码，我们就会用到本模式。

## 实现

### 1.定义工厂方法所创建对象的接口
假设我们的存储模块只有**Read**和**Write**两个功能，我们需要先定义存储器**inteface**。

```go
package store

import "io"

type Store interface {
    Read(string) ([]byte, error)
    Save(string, []byte) (error)
}
```

### 2.实现对象接口

假设我们需要将Redis或磁盘作为存储介质，我们需要分别实现Redis与磁盘的存储功能。

#### FileSystem
```go
pacakge store

type FileStore struct{
  /*your codes*/
}

func (store *FileStore) Read(string) ([]byte, error) {
  /*your codes*/
}

func (store *FileStore) Save(string, []byte) (error) {
  /*your codes*/
}

// 注意这里要返回 Store 接口，而不是FileStore的指针。
// 可以保证工厂方法只能调用到对象接口方法，避免封装被破坏。
func newFileStore() Store {
  /*your codes*/
}
```

#### Redis
```go
pacakge store

type RedisStore struct{
  /*your codes*/
}

func (store *RedisStore) Read(string) ([]byte, error) {
  /*your codes*/
}

func (store *RedisStore) Save(string, []byte) (error) {
  /*your codes*/
}

// 注意这里要返回 Store 接口，而不是RedisStore的指针。
// 可以保证工厂方法只能调用到对象接口方法，避免封装被破坏。
func newRedisStore() Store {
  /*your codes*/
}
```

### 3.实现工厂方法

工厂方法是暴露给模块外部使用的，用于创建实例的方法。我们需要将各种类型**Store**实例的创建过程封装到该方法里面，避免暴露给外部模块。由工厂方法统一提供创建功能。

```go
pacakge store

type (
  StoreType int
)

const (
  File StorageType = 1 << iota
  Redis
)

func NewStore(storeType StoreType) Store {
  switch storeType {
    case File:
      return newFileStore()
    case Redis:
      return newRedisStore()
    default:
      panic("尚未支持的存储类型！")
  }
}
```

## 使用

假设我们需要使用**Redis**作为存储介质，我们只需要在工厂方法中传入**store.Redis**参数。

```go
package main

import (
  "fmt"

  "xxxx/store" // 你的模块地址
)

func main() {
  st := store.NewStore(store.Redis)

  // 读取数据
  data, err := st.Read("/foo")
  fmt.Println(err, data)

  // 保存数据
  err = st.Write("/foo", data)
  fmt.Println(err)
}
```

如果现在我们想更换介质为文件系统，我们只需要更换工厂方法中传入的参数为**store.File**即可完成介质更换。

```go
// 其他代码不变

// 工厂方法的参数更改为store.File即可。
st := store.NewStore(store.File)

// 其他代码不变
```
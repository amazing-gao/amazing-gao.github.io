---
title: "Go Code Review"
slug: /go/codereview
description: Go Code Review Guide
date: 2021-10-22T10:40:09+08:00
type: posts
draft: false
toc: true
featured: false
categories:
  - go
tags:
  - go
  - code reivew
series:
  -
---

> 以此记录那些年 Code Review 遇到的坑😂。

## 变量作用域

> 变量应该遵循最小作用域的原则，否者可能引起错乱。

### 案例1

函数的功能是：将 MongoDB 数据库中所有 offline 是 false 的记录，同步到 Redis 中。

#### Bad

`tmpl` 的作用域在 `for` 循环之外，在对每条查询结果做 `cursor.Decode` 时 `tmpl` 变量未被重置，这造成之前记录的值可能残留在这次 `cursor.Decode` 的结果中，从而导致数据错乱。

```go
func Foo(ctx context.Context) error {
  cursor, err := mongodb.Database("baz").Collection("qux").Find(ctx, mongodb.M{"offline": false})

  // tmpl 的作用域是在 for 循环之外
  tmpl := &Tmpl{}
  for cursor.Next(ctx) {
    if err := cursor.Decode(tmpl); err != nil {
      return err
    }

    bytes, err := json.Marshal(tmpl)
    if err != nil {
      return err
    }

    if err := redis.Client().Set(ctx, tmpl.Id, string(bytes), 0).Err(); err != nil {
      return err
    }
  }
}
```

#### Good

要怎么避免这个问题呢？

在这个例子中我们很容易看出 `tmpl` 只在 `for` 循环内部使用，按照原则应该被放置到循环内部，在循环的过程中每次都是新值就不存在残留数据的问题了。

```go
func Foo(ctx context.Context) error {
  cursor, err := mongodb.Database("baz").Collection("qux").Find(ctx, mongodb.M{"offline": false})

  for cursor.Next(ctx) {
    tmpl := &Tmpl{}

    if err := cursor.Decode(tmpl); err != nil {
      return err
    }

    bytes, err := json.Marshal(tmpl)
    if err != nil {
      return err
    }

    if err := redis.Client().Set(ctx, tmpl.Id, string(bytes), 0).Err(); err != nil {
      return err
    }
  }
}
```
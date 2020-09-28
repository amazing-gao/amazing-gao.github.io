---
title: "Go工具链之godoc指南"
slug: godoc
description: godoc使用指南
date: 2020-09-27T21:30:30+08:00
type: posts
draft: false
categories:
  - go
tags:
  - go
  - godoc
series:
  - Go工具链
typora-root-url: ../../static
---

在写[boxgo](https://github.com/boxgo/box)的过程中，想要生成漂亮的godoc，发现不太熟悉godoc的用法，所以就有了本篇文章，记录一下。

Go团队非常重视文档，文档对项目的可阅读性、可维护性起到重要作用，所以写好文档变得非常重要。Go团队提供了`godoc`工具以帮助开发者方便、准确，容易的生成项目文档。`godoc`解析Go源代码（包括注释），并以HTML或纯文本格式生成文档。

# 生成文档

提取规则：

1. 类型、变量、常量、函数，包都可以通过在声明的前面写注释的方法生成文档（中间不要有空行）。

   ```go
   // Package doc 包注释  --- good
   package doc
   
   type (
     // UserType 类型注释  --- good
     UserType string
   )
   
   var (
     // userType 变量注释  --- good
     userType UserType
   )
   
   const (
     // Zero 常量注释  --- good
     Zero = 0
   )
   
   // Test 函数注释  --- good
   func Test() {
   
   }
   
   
   // Test1 函数注释  --- bad（不要有空行）
   
   func Test1() {
   
   }
   ```

2. 注释开头的字母需要与被注释的元素名称保持一致（`包`除外）。如函数`Fprint`注释开头的第一个字母也是`Fprint`。

   ```go
   // Fprint formats using the default formats for its operands and writes to w.
   // Spaces are added between operands when neither is a string.
   // It returns the number of bytes written and any write error encountered.
   func Fprint(w io.Writer, a ...interface{}) (n int, err error) {
     //
   }
   ```

3. `doc.go` - 包注释比较多的话也可以使用单独的`doc.go`来编写文档。参考[gob package's doc](https://golang.org/src/encoding/gob/doc.go)。

4. `BUG(who)` - 注释与被注释主体之间通常不能有空行或者空注释，但是`BUG(who)`是一个例外，`BUG`将在godoc的文档中展示。参考：[bytes package](https://golang.org/pkg/bytes/#pkg-note-BUG)。

   ```go
   // Title treats s as UTF-8-encoded bytes and returns a copy with all Unicode letters that begin
   // words mapped to their title case.
   //
   // BUG(rsc): The rule Title uses for word boundaries does not handle Unicode punctuation properly.
   func Title(s []byte) []byte {
   ```

5. `Deprecated` - 可以描述struct field, function, type, variable, const甚至是package，表示被弃用，后续不再使用，但必须保持兼容性。

6. 多个相邻的注释行，生成文档时被视为一个段落，如果想要生成多个段落，请留空行。

7. 预格式文本需要相对上下文的注释有缩进。

8. URL无需标记，文档中也会被转换成URL。

# 查看文档

几行代码带你查看你项目的godoc。

```sh
# 进入你的项目源代码目录
cd $your_project_dir

# 为项目建立软连接，因为godoc目前对go mod支持的不是很好，所以需要将项目软链到GOPATH内。如果你的项目在GOPATH目录中，跳过此步骤。
ln -s $your_project_dir $GOPATH/src/$your_module_path

# 启动godoc服务
godoc -http=":6060"

# mac下查看文档。其他操作系统请打开浏览器访问。
open http://127.0.0.1:6060/pkg/$your_module_path
```

效果图

![image-20200928161749381](/posts/godoc/image-20200928161749381.png)

# 参考文档

[godoc command](https://pkg.go.dev/golang.org/x/tools/cmd/godoc)

[godoc blog](https://blog.golang.org/godoc)


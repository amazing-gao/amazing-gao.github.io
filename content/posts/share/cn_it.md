---
title: "基于信创的互金应用探索与实践"
slug: /sahre/cn-it
description: 信创二字来源于“信息技术应用创新工作委员会”。2016年3月4日工委会成立，是由从事信息技术软硬件关键技术研究、应用和服务的企事业单位发起建立的非营利性社会组织。
date: 2021-08-12T17:16:02+08:00
type: posts
draft: false
toc: true
featured: true
categories:
  -
tags:
  - Docker
  - Go
  - Gitlab
  - 信创
series:
  -
---

## 信创是什么？

信创二字来源于“信息技术应用创新工作委员会”。2016年3月4日工委会成立，是由从事信息技术软硬件关键技术研究、应用和服务的企事业单位发起建立的非营利性社会组织。

信创产业，即信息技术应用创新产业。**信创产业推进的背景在于，过去中国IT底层标准、架构、产品、生态大多数都由国外IT商业公司来制定，由此存在诸多的底层技术、信息安全、数据保存方式被限制的风险。**

全球IT生态格局将由过去的“一极”向未来的“两极”演变，**中国要逐步建立基于自己的IT底层架构和标准**。基于自有IT底层架构和标准建立起来的IT产业生态便是信创产业的主要内涵。

## 跟我们有什么关系？

根据中国证监会科技监管局《关于建立信息技术应用创新工作一把手责任制的通知》（[2021]221号文）要求，公司决定成立信创工作领导小组和执行小组，xx、xx有幸被选中作为首批的试点项目。

## 我们要做什么？

简单来说，我们的远期目标是实现全面国产化，说实话从我个人来看的话目标的难度非常大，非常具有挑战性。我们的短期目标是什么呢？实现应用程序的国产CPU服务器和国产数据库化。

![:inline](/posts/share/cn_it_arch.jpeg)

### 国产CPU服务器

国产CPU服务器化，对应用侧来说就是将程序部署于国产CPU的服务器之上，目前我们互联网金融的应用程序均部署于公司的微服务平台 — Eagle。

国产服务器硬件层面由 Eagle 与公司基础运维组 统一采购、部署、管理，对于应用侧来说只需将应用程序发布到相应的信创集群即可，那么 Eagle 方面目前提供了哪些方案呢？

| 操作系统     | 操作系统研发单位 | CPU型号 | CPU研发单位 | CPU指令集体系 | CPU架构来源 | 是否就绪             |
| :----------- | :--------------- | :------ | :---------- | :------------ | :---------- | :------------------- |
| 银河麒麟 V10 | 麒麟软件         | 鲲鹏920 | 华为        | ARM           | 指令集授权  | 是（集群标签armcs1） |
| 银河麒麟 V10 | 麒麟软件         | 飞腾    | 天津飞腾    | ARM           | 指令集授权  | 否                   |
| 银河麒麟 V10 | 麒麟软件         | 海光    | 天津海光    | x86（AMD）    | IP授权      | 否                   |

Eagle 主推“麒麟+鲲鹏“方案；考虑到服务器交付风险，增加”麒麟+飞腾“备选方案；考虑到业务系统向 ARM 平台迁移改造的适配风险，增加”麒麟+海关“备选方案。

信创主推和备选的是自主化程度较高、基于 ARM 指令集体系方案，对于应用侧来说也是改造最多的，所以这是我们重点关注的方案。

#### ARM VS x86

ARM 与 x86 最本质上的区别是指令集的差异，ARM 使用 RISC 精简指令集，而 x86 使用 CISC 复杂指令集。

比如我们在使用 Go 编写应用时，我们的源代码会根据目标平台的指令集架构编译成特定平台的机器码。而不同平台的机器码是不兼容的，所以我们需要针对目标平台进行编译。

| **ARM**                                                      | **X86**                                                      |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| Uses Reduced Instruction Set computing Architecture (RISC).  | Uses Complex Instruction Set computing Architecture (CISC).  |
| Executes single instruction per cycle.                       | Executes complex instruction at a time, and it takes more than a cycle. |
| Optimization of performance with Software focused approach.  | Hardware approach to optimize performance.                   |
| Requires less registers, more memory.                        | It uses more registers and less memory                       |
| Pipelining of instructions is a unique feature.              | Less pipelined.                                              |
| Faster Execution of Instructions reduces time.               | Time to execute is more.                                     |
| Complex addressing is managed by software.                   | Inherently designed to handle complex addresses.             |
| Compiler plays a key role in managing operations.            | The micro program does the trick.                            |
| Multiple Instructions are generated from a complex one and executed individually. | Its Architecture is capable of managing complex statement execution at a time. |
| Managing code expansion is difficult.                        | Code expansion is managed easily.                            |
| Decoding of instruction is handled easily.                   | Decoding is handled in a complex way.                        |
| Uses available memory for calculations.                      | Needs supplement memory for calculations.                    |
| Deployed in mobile devices where size, power consumption speed matters. | Deployed in Servers, Desktops, Laptops where high performance and stability matters. |

### 国产数据库

国产数据库化，将应用程序使用的数据库迁移到国产数据库。目前公司国产数据库的建设方案尚未完全敲定，已POC以下厂商的解决方案：

关系数据库：TiDB、OceanBase、达梦、GoldenDB，神州通用、PolarDB

非关系数据库：暂无

## 怎么做？

由于国产数据库仍在POC阶段，并且MongoDB等非关系数据库尚无计划支持，所以目前我们主要谈谈国产CPU服务器化的一些实践。

在前面已经提到我司主推的国产CPU服务器采用 ARM 架构，而我们的应用程序和制品均是 x86 架构，所以我们的主要任务是：
  1. 应用程序的可执行文件编译为 ARM 架构
  2. 应用程序的动态依赖库更新为 ARM 架构
  3. 应用程序的基础镜像或运行时镜像更新为 ARM 架构
可见实质上我们要做的就是 x86 到 ARM 的迁移。

### 构建 ARM 应用程序

由于编程语言之间的差异，构建 ARM 应用程序的方案也不尽相同，下面简单介绍几门常用语言的大概情况。

对于 Go/C/C++ 等编译型的静态语言来说

1. 在 ARM 机器进行本地编译，生成 ARM 可执行文件
2. 在 x86_64  机器进行交叉编译，生成 ARM 可执行文件

构建 ARM 制品最简单的方案是上文中方案1。但目前我们并没有获取到 ARM 的机器，所以暂时只能先走交叉编译这条路。

对于 Go 来说，交叉编译非常简单，官方提供的工具链已经提供交叉编译的能力，我们只需要在编译的过程中稍作如下修改即可：

```
GOOS=linux GOARCH=arm64 go build -o app main.go
```

对于 Node.JS 来说，如果你的代码和依赖都是纯JS的，不涉及到 C++ 编译，那么你只需要使用 ARM 版本的运行时运行程序即可。但如果涉及到 C++ 编译时，Node.JS 并未提供交叉编译的能力，你还是需要在 ARM 机器上进行编译。

对于 Java 来说，情况与 Node.JS 类似，使用 ARM 版 JVM 即可，JVM 提供了一层抽象，可以屏蔽底层 CPU 架构的差异，除非涉及一些 Native 的调用。

### 构建 ARM 镜像

构建 ARM 镜像也要面临两个选择：

1. 在 ARM 机器上安装 arm64 版本 Docker Engine 进行本地镜像构建，生成 ARM 镜像
2. 在 x86_64 机器上安装 x86_64 版本 Docker Engine 进行交叉镜像构建，生成 ARM 镜像

由于没有 ARM 机器，继续挑战 HARD 模式。

#### 多CPU架构镜像

在挑战之前，我们需要先简单了解一下 Docker 镜像的多 CPU 架构。

Docker 镜像支持 Multiple Architectures，也就是说一个镜像可以包含不同 CPU 架构的多个子镜像。在我们拉取或者运行镜像时，Docker 会自动根据当前运行环境拉取相适配的子镜像运行。

![:inline](/posts/share/docker_image_manifest.png)

举个例子，我们可以去官方查看 alpine:latest 的镜像，如下图：

![:inline](/posts/share/alpine.png)

该镜像包含多个 OS/ARCH 的子镜像，我们在本地（MacOS）使用如下命令：

```
docker pull alpine:latest docker inspect alpine:latest
```

可以看到如下两个关键信息 Os: linux，Architecture: amd64，我没有指定就根据我的运行环境进行了拉取。

![:inline](/posts/share/alpine1.png)

#### 使用 buildx 构建跨平台镜像

Docker buildx 是 Moby/BuildKit 提供的一套 docker 命令行构建工具插件。buildx 可以使用 QEMU 作为模拟器来构建或者运行 ARM, x86_64 等多个CPU架构的 docker 镜像。

1. Familiar UI from docker build
2. Full BuildKit capabilities with container driver
3. Multiple builder instance support
4. Multi-node builds for cross-platform images
5. Compose build support
6. High-level build constructs (bake)
7. In-container driver support (both Docker and Kubernetes)


关于 QEMU 不是本文的重点，这里不做过多的介绍，简而言之 Qemu 是纯软件实现的虚拟化模拟器，几乎可以模拟任何硬件设备，buildx 借助它模拟不同CPU架构的运行环境来构建镜像。

![:inline](/posts/share/qemu.png)

开始构建镜像，请按以下步骤操作

1. 宿主机的 Docker >= 19.03，Linux kernel >= 4.8，binfmt-support >= 2.1.7

2. 开启 Docker 的实现性特性

```sh
export DOCKER_CLI_EXPERIMENTAL=enabled
```

3. 下载并安装 buildx 可执行文件

```sh
# 下载 buildx
curl -o ~/.docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/v0.6.0/buildx-v0.6.0.linux-amd64
# 更新权限
chmod a+x ~/.docker/cli-plugins/docker-buildx
# 查看 buildx 版本，确定是否安装成功
docker buildx version
# 输出 github.com/docker/buildx v0.6.0-docker 11057da37336192bfc57d81e02359ba7ba848e4a
```

4. 注册 QUME 到宿主机

```sh
docker run --privileged --rm tonistiigi/binfmt --install all
```

5. 创建并启用 builder

```sh
# 创建并启用 mybuilder
docker buildx create --use --name mybuilder
# 查看 mybuilder 支持的构建
docker buildx ls
# 输出：default default running linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6
```

6. 编写 Go 应用代码

```go
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		fmt.Println("GET /ping")
		fmt.Fprintf(w, "pong\n")
	})

	log.Println("server start listen ...")
	log.Fatal(http.ListenAndServe(":9000", nil))
}
```

7. 编写 Dockerfile

```Dockerfile
# Go 可执行文件构建阶段
FROM --platform=$TARGETPLATFORM xxxx/sni-be/go:1.16-alpine3.14 AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM"

RUN mkdir /app
ADD . /app
WORKDIR /app

RUN go build -o /app/server .


# Go 可执行文件运行环境构建阶段
FROM --platform=$TARGETPLATFORM xxxx/sni-be/alpine:3.11

COPY --from=builder /app/server /go/bin/server
ADD config /go/bin/config

WORKDIR /go/bin
ENTRYPOINT [ "/go/bin/server" ]
```

8. 构建 ARM 镜像并 push 到仓库

```sh
# 构建同时支持 arm 和 amd64 的镜像，并以 oci 格式将镜像输出到本地
docker buildx build --platform=linux/arm64,linux/amd64 -o type=oci,dest=- . > image-oci.tar

# 将镜像上传到镜像仓库
# 为什么用 skopeo，而不是直接 push 呢？因为我司在建的镜像仓库不支持 buildx 的镜像 push 。
skopeo copy -a oci-archive:image-oci.tar docker://xxxx/templates/cicd:xman

# 查看镜像
docker buildx imagetools inspect xxxx/templates/cicd:xman
```

   ![:inline](/posts/share/xman.png)


9. 发布到 Eagle，可以看到

   ![:inline](/posts/share/eagle.png)
   ![:inline](/posts/share/eagle1.png)

### 是骡子是马，拉出来溜溜

方案：使用 ab 以 200 并发压测 10w 次，进行多轮，选最好成绩对比。

#### ARM

```
# ab -n 100000 -c 200 eagle_armcs1:32025/api/xxxx/demo/1.0.0/ping

This is ApacheBench, Version 2.3 <$Revision: 1843412 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking eagle_armcs1 (be patient)
Completed 10000 requests
Completed 20000 requests
Completed 30000 requests
Completed 40000 requests
Completed 50000 requests
Completed 60000 requests
Completed 70000 requests
Completed 80000 requests
Completed 90000 requests
Completed 100000 requests
Finished 100000 requests


Server Software:        nginx/1.18.0
Server Hostname:        eagle_armcs1
Server Port:            32025

Document Path:          /api/xxxx/demo/1.0.0/ping
Document Length:        5 bytes

Concurrency Level:      200
Time taken for tests:   5.893 seconds
Complete requests:      100000
Failed requests:        0
Total transferred:      16200000 bytes
HTML transferred:       500000 bytes
Requests per second:    16970.17 [#/sec] (mean)
Time per request:       11.785 [ms] (mean)
Time per request:       0.059 [ms] (mean, across all concurrent requests)
Transfer rate:          2684.73 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    5  25.5      4    1034
Processing:     1    7   8.9      5     267
Waiting:        1    7   8.1      5     267
Total:          1   11  27.0     10    1039

Percentage of the requests served within a certain time (ms)
  50%     10
  66%     11
  75%     11
  80%     12
  90%     16
  95%     21
  98%     28
  99%     33
 100%   1039 (longest request)
```

![:inline](/posts/share/eagle_arm64.png)

#### x86

```
# ab -n 100000 -c 200 eagle_cs8:32025/api/xxxx/demo/1.0.0/ping

This is ApacheBench, Version 2.3 <$Revision: 1843412 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking eagle_cs8 (be patient)
Completed 10000 requests
Completed 20000 requests
Completed 30000 requests
Completed 40000 requests
Completed 50000 requests
Completed 60000 requests
Completed 70000 requests
Completed 80000 requests
Completed 90000 requests
Completed 100000 requests
Finished 100000 requests


Server Software:        nginx/1.10.2
Server Hostname:        eagle_cs8
Server Port:            32025

Document Path:          /api/xxxx/demo/1.0.0/ping
Document Length:        5 bytes

Concurrency Level:      200
Time taken for tests:   5.034 seconds
Complete requests:      100000
Failed requests:        0
Total transferred:      16200000 bytes
HTML transferred:       500000 bytes
Requests per second:    19863.21 [#/sec] (mean)
Time per request:       10.069 [ms] (mean)
Time per request:       0.050 [ms] (mean, across all concurrent requests)
Transfer rate:          3142.42 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    5  51.6      2    1035
Processing:     1    4  10.1      4     236
Waiting:        1    4   9.3      3     231
Total:          1   10  52.6      6    1039

Percentage of the requests served within a certain time (ms)
  50%      6
  66%      7
  75%      8
  80%      8
  90%     11
  95%     14
  98%     27
  99%     31
 100%   1039 (longest request)
```

![:inline](/posts/share/eagle_x86.png)

通过压测报告的 QPS 与 CPU 对比来看，ARM 机器与 x86 还是存在一定的差距。

### 持续集成

对于有志成为 10x Programmer 的我们来说，上面的步骤太繁琐，能不能简单点优雅点，我自己就有4,50个项目要改造啊啊啊！

来了来了，它来了：http://xxxx/templates/cicd

我们以 Go 项目为例，先如下改造 Dockerfile，再更新 .gitlab-ci.yml 文件即可。

#### 改造 Dockerfile

```Dockerfile
FROM --platform=$TARGETPLATFORM xxxx/sni-be/go:1.16-alpine3.14 AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN mkdir /app
ADD . /app
WORKDIR /app

RUN go build -o /app/server .


FROM --platform=$TARGETPLATFORM xxxx/sni-be/alpine:3.11

COPY --from=builder /app/server /go/bin/server
ADD config /go/bin/config

WORKDIR /go/bin
ENTRYPOINT [ "/go/bin/server" ]
```

#### 改造 .gitlab-ci.yml

```yaml
include:
  - '/.gitlab-ci/dockerx.yml'
  - '/.gitlab-ci/eagle.yml'

stages:
  - docker
  - deploy

variables:
  ARM_ENABLE: "yes"
  WORKDIR: example_go_buildx
  EAGLE_TEMPLATE_ID: demo-xxxx-1.0.0-kxc1mc1mcuat
  EAGLE_TEMPLATE_ID_TEST: demo-xxxx-1.0.0-armcs1cs8

```

为什么可以这么方便？是因为上面的过程全部都集成到 CICD 的模版中了。

## 展望未来

有人说搞这些是在开倒车，有人说我们又搞起了闭关锁国，也有人说我们会像日本一样步入失去的20年，我选择相信习大大的版本：`道阻且长，行则将至；行而不辍，未来可期。`

## FAQ

### 迁移太麻烦、太困难，我想直接运行 X86 的应用程序或者镜像行不行？

### 如何将 Docker Hub 的多 CPU 架构基础镜像迁移到公司内部？

前面我们已经提到如果使用 docker pull 的方式拉取镜像，我们只能拉取到当前系统 CPU 架构的镜像，这显然不满足我们的需求。

我们以 alpine:3.11 为例，Docker Hub 支持的 CPU 架构非常多。我们可以使用 skopeo copy 命令一键完成迁移。通过下图可以看到迁移到公司仓库的镜像也保持了同样的 OS/ARCH。


```sh
skopeo copy -a docker://docker.io/library/alpine:3.11 docker://xxxx/sni-be/alpine:3.11
```

### buildx 编译时 moby/buildkit 时无法下载或下载太慢，肿么办？

在构建镜像的机器上创建并启用 builder 时，如下设置本地 buildkit 镜像：

```sh
docker buildx create --driver-opt image=xxxx/moby/buildkit:latest --use
```

### 使用到 node-oracledb 安装错误

```sh
#21 218.6 npm ERR! code 87
#21 218.6 npm ERR! path /opt/app/node_modules/oracledb
#21 218.6 npm ERR! command failed
#21 218.6 npm ERR! command sh -c node package/install.js
#21 218.6 npm ERR! oracledb ERR! NJS-067: a pre-built node-oracledb binary was not found for linux arm64
#21 218.6 npm ERR! oracledb ERR! Try compiling node-oracledb source code using https://oracle.github.io/node-oracledb/INSTALL.html#github
```

错误说的很清楚了，也有人问了同样的问题：https://github.com/oracle/node-oracledb/issues/1382

预编译好的只有x64_64的，arm需要自己编译。

### 用到的镜像

用到或者迁移过来的一些 arm64 & amd64 的镜像

| 说明                 | 镜像地址                                                     |
| -------------------- | ------------------------------------------------------------ |
| go 16.3              | [xxxx/sni-be/go:v1.0.0](http://xxxx/sni-be/go:v1.0.0) |
| alpine 3.13          | [xxxx/sni-be/runtime:v1.0.0](http://xxxx/sni-be/runtime:v1.0.0) |
| node 6.11.5          | [xxxx/sni-be/runtime:node6.11.5](http://xxxx/sni-be/runtime:node6.11.5) |
| node 16              | [xxxx/sni-be/runtime:node16-alpine3.14](http://xxxx/sni-be/runtime:node16-alpine3.14) |
| dind with buildx     | [xxxx/sni-be/dindx:latest](http://xxxx/sni-be/dindx:latest) |
| moby build kit       | [xxxx/moby/buildkit:latest](http://xxxx/moby/buildkit:latest) |
| gitlab runner helper | [xxxx/sni-be/gitlab-runner-helper:alpine](http://xxxx/sni-be/gitlab-runner-helper:alpine) |



## 参考文档

1. [经济参考报 - 信创](http://www.jjckb.cn/2021-03/11/c_139801586.htm)
2. [信息技术应用创新工作委员会](https://www.itaic.org.cn/)
3. [中国信创产业发展白皮书2021](http://eversec.com.cn/wp-content/uploads/2020/08/中国信创产业发展白皮书2021.pdf)
4. [Difference Between ARM vs X86](https://www.educba.com/arm-vs-x86/)
5. [Multiple Architectures](https://github.com/docker-library/official-images#multiple-architectures)
6. [Build multi-arch images with Buildx](https://docs.docker.com/desktop/multi-arch/)
7. [Image Manifest V 2, Schema 2](https://docs.docker.com/registry/spec/manifest-v2-2/)
8. [Building multi-platform images](https://github.com/docker/buildx#building-multi-platform-images)
9. [Qemu](https://www.cnblogs.com/bakari/p/7858029.html)


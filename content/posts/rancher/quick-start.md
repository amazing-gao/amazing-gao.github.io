---
title: "Rancher初体验"
slug: quick-start
description: Rancher 是为使用容器的公司打造的容器管理平台。Rancher 简化了使用 Kubernetes 的流程，开发者可以随处运行 Kubernetes（Run Kubernetes Everywhere），满足 IT 需求规范，赋能 DevOps 团队。这次我们来初次体验一下Rancher到底做的怎么样。
date: 2021-02-06T16:47:59+08:00
type: posts
draft: false
toc: true
featured: true
categories:
  - rancher
tags:
  - rancher
  - k8s
  - docker
  - devops
series:
  - rancher系列
---

## Kubernetes 是什么？

在技术圈大家对大名鼎鼎的 Kubernetes（别名k8s）肯定都是耳熟能详，无论过去、现在和未来，它都将对世界产生非常深远的积极影响。

在此借用[官方介绍](https://kubernetes.io/zh/docs/concepts/overview/what-is-kubernetes/)：

    Kubernetes 是一个可移植的、可扩展的开源平台，用于管理容器化的工作负载和服务，可促进声明式配置和自动化。
    Kubernetes 拥有一个庞大且快速增长的生态系统。Kubernetes 的服务、支持和工具广泛可用。
    名称 Kubernetes 源于希腊语，意为“舵手”或“飞行员”。Google 在 2014 年开源了 Kubernetes 项目。
    Kubernetes 建立在 Google 在大规模运行生产工作负载方面拥有十几年的经验 的基础上，结合了社区中最好的想法和实践。

## Rancher 是什么？

在此还是借用[官方介绍](https://docs.rancher.cn/docs/rancher2/overview/_index/)：

    Rancher 是为使用容器的公司打造的容器管理平台。
    Rancher 简化了使用 Kubernetes 的流程，开发者可以随处运行 Kubernetes（Run Kubernetes Everywhere），
    满足 IT 需求规范，赋能 DevOps 团队。

简而言之 Rancher 基于 k8s 平台，旨在打造一个更易用、更全面、更安全的容器管理平台。Rancher 提供了一系列企业级服务亟需的开箱即用的功能，大大简化了团队上手的成本。
*我觉得它适用于那些想使用容器管理平台 ，但是觉得 k8s 非常复杂又太基础，二次开发 k8s 没有精力和实力的团队。如果你们是这样的团队，我强烈建议你们考虑一下。*

出于此目的与好奇心，所以我们来初体验一下。

## 初体验

本次我们的目的是在 Mac 下安装 Rancher 并发布一个 nginx 服务。

本人环境如下：
* OS: macOS 10.15.7
* Docker Engine: 20.10.2
* Kubernetes: v1.19.3


### 安装 Docker
如果你还没有安装 Docker，请先[下载并安装](https://desktop.docker.com/mac/stable/Docker.dmg)。这里我们就不介绍 Docker的安装过程了。

安装完成之后，打开 Docker 的 【Preferences】-> 【Kubernetes】，见到如下图：

### 安装 Kubernetes
![:inline](/posts/rancher/docker-k8s-settings.png)

勾选 【Enable Kubernetes】和 【Deploy Docker Stacks to Kubernetes by default】，点击【Apply & Restart】即可自动安装 Kubernetes。

安装过程可能比较慢，这取决于你的网络，最好带个梯子。

当我们看到右下角 k8s 的状态是绿色（running）时，表示我们的 k8s 已经安装并运行正常。

![:inline](/posts/rancher/docker-k8s-running.png)

到这里，我们的 k8s 已经安装正常了，下面我们来启动我们的主角 Rancher。

### 启动 Rancher

由于是本机安装体验试用，我们选择 [单节点安装](https://docs.rancher.cn/docs/rancher2/installation_new/other-installation-methods/single-node-docker/_index/) 方案，生产环境请大家一定使用高可用方案。

执行以下命令下载并启动 Rancher ，在这里我们选择的是 `rancher v2.4.13` 。

```sh
docker run -d \
    --restart=unless-stopped \
    -p 80:80 -p 443:443 \
    rancher/rancher:v2.4.13
```

执行成功之后，使用浏览器打开 `http://192.168.50.162` （请换成你的局域网IP访问，不要使用127.0.0.1或者localhost）。然后设置你的登录账号密码，进入系统。

点击【添加集群】。
![:inline](/posts/rancher/rancher-cluster-add.png)

点击【导入】导入我们本地默认的 k8s 集群。
![:inline](/posts/rancher/rancher-cluster-import.png)

输入【集群名称】，点击【创建】集群。
![:inline](/posts/rancher/rancher-cluster-create.png)

由于我们没有配置证书，所以 Copy 最后一种方式导入。
![:inline](/posts/rancher/rancher-cluster-create1.png)

这时我们进入集群管理界面，看到 `Controller Manager` 和 `Schedule` 组件工作异常。
![:inline](/posts/rancher/rancher-cluster-status.png)

搜索 github issue，看到已经有人提了这个 BUG，并提了一个 workaround 的方案，请看 [issues#28802](https://github.com/rancher/rancher/issues/28802)。

原因是 `kubectl get componentstatuses` 在 `k8s 1.19` 被作废了，但是目前版本的 rancher 都是用的此方法获取状态。[原因详情](https://github.com/kubernetes/kubernetes/issues/93342)。

issue中提出的解决方案，删除下面两个文件中的 `--port=0` 配置（新版本已禁用 --port 参数，所以需要删除）：

    /etc/kubernetes/manifests/kube-controller-manager.yaml
    /etc/kubernetes/manifests/kube-scheduler.yaml

但是在 macOS 上，docker 中的镜像是运行在虚拟机中的，也就是说 *macOS -> Linux虚拟机 -> Docker* 。所以我们的 k8s 配置文件也在虚拟机中，macOS 中并没有上面的两个文件。

所以我们需要研究如何进入 macOS 中的虚拟机，好在已经有很多前辈遇到过这个问题了，我参考 [HOW TO LOGIN THE VM OF DOCKER DESKTOP FOR MAC
](https://www.dbform.com/2019/07/08/how-to-login-the-vm-of-docker-desktop-for-mac/) 这篇文章找到了解决方案。

简言之，一行命令进入虚拟机：

```sh
docker run -it --rm --privileged --pid=host justincormack/nsenter1
```

虽然是拿来的，但是我们也要进行消化一下，为什么这样子就可以进入虚拟机了呢？

* `–privileged` 表示允许该容器访问宿主机（也就是我们想要登录的VM）中的各种设备
* `–pid=host` 表示允许容器共享宿主机的进程命名空间（namespace），或者通俗点儿解释就是允许容器看到宿主机中的各种进程
* [nsenter](http://man7.org/linux/man-pages/man1/nsenter.1.html) 是一个小工具允许我们进入一个指定的namespace然后运行指定的命令，ns=namespace，enter=进入。
  * 样例：nsenter -t 1 -m -u -n -i sh
    * -t 1: 表示要进入哪个pid，1表示整个操作系统的主进程id
    * -m: 进入mount namespace，挂载点
    * -u: 进入UTS namespace，也就是上面我们演示的那个namespace
    * -n: 进入network namespace，网络
    * -i: 进入IPC namespace，进程间通信
    * sh: 表示运行/bin/sh

终于，我们进入到虚拟机里面了，然后更新删除 `--port` 参数，发现服务已经正常了。

![:inline](/posts/rancher/rancher-cluster-status-ok.png)

现在我们可以发布我们的服务了。
![:inline](/posts/rancher/rancher-service-deploy.png)

现在来输入我们要创建的 nginx 服务信息，并点击【启动】。
![:inline](/posts/rancher/rancher-service-deploy1.png)

回到【工作负载】页面，看到我们的 nginx 服务已经启动成功过了，并随机分配了32211端口。
![:inline](/posts/rancher/rancher-service-status.png)

使用浏览器打开 *http://localhost:32211/* ，看到了我们熟悉的 nginx 页面。

![:inline](/posts/rancher/nginx.png)

剩下的时间就随便点点看看，Rancher 有哪些功能吧。

## 体验总结

可以看到 Rancher 做的还是非常全面且友好的，实现了 RBAC 权限管理，自带日志、监控、告警，无缝对接云厂商，无缝对接已有 K8S 集群并支持各类管理功能。

本次体验到此结束，总得来说 Rancher 确实一个不错的产品，值得深入了解与使用。

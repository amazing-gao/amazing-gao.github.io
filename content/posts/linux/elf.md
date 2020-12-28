---
title: "ELF格式简介"
slug: /linux/elf
description: null
date: 2020-12-28T10:56:34+08:00
type: posts
draft: false
toc: true
featured: true
categories:
  - linux
  - unix
tags:
  - linux
  - unix
  - ELF
series:
  -
---

## 概要

[ELF](https://en.wikipedia.org/wiki/Executable_and_Linkable_Format) 是一种文件格式。首次发布在名为 System Release 4 的 Unix 操作系统版本的 [ABI](https://en.wikipedia.org/wiki/Application_binary_interface) 规范中，后来使用在 Tool interface standard中，然后迅速被不同的 Unix 发行版使用。在1999年，ELF 被选为 Unix 和 Unix-like 系统x86处理器的标准二进制文件格式。

## 文件格式

ELF 文件由 ELF File Header 和 Data 组成，Data 又由以下部分组成：
1. Program header table
2. Section header table
3. 1, 2 表头中引用的数据

![ELF Format](/posts/linux/elf/elf.png)

### ELF file header

![:inline](/posts/linux/elf/elf_header1.png)
![:inline](/posts/linux/elf/elf_header2.png)
![:inline](/posts/linux/elf/elf_header3.png)

### Program header

![Program header](/posts/linux/elf/program_header.png)

### Section header

![Section header](/posts/linux/elf/section_header.png)

## 示例

```sh
readelf -all a.out
```

```
 ELF Header:
   Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
   Class:                             ELF64
   Data:                              2's complement, little endian
   Version:                           1 (current)
   OS/ABI:                            UNIX - System V
   ABI Version:                       0
   Type:                              EXEC (Executable file)
   Machine:                           Advanced Micro Devices X86-64
   Version:                           0x1
   Entry point address:               0x4003e0
   Start of program headers:          64 (bytes into file)
   Start of section headers:          2488 (bytes into file)
   Flags:                             0x0
   Size of this header:               64 (bytes)
   Size of program headers:           56 (bytes)
   Number of program headers:         8
   Size of section headers:           64 (bytes)
   Number of section headers:         30
   Section header string table index: 27

 Section Headers:
   [Nr] Name              Type             Address           Offset
        Size              EntSize          Flags  Link  Info  Align
   [ 0]                   NULL             0000000000000000  00000000
        0000000000000000  0000000000000000           0     0     0
   [ 1] .interp           PROGBITS         0000000000400200  00000200
        000000000000001c  0000000000000000   A       0     0     1
   [ 2] .note.ABI-tag     NOTE             000000000040021c  0000021c
        0000000000000020  0000000000000000   A       0     0     4
   [ 3] .note.gnu.build-i NOTE             000000000040023c  0000023c
        0000000000000024  0000000000000000   A       0     0     4
   [ 4] .gnu.hash         GNU_HASH         0000000000400260  00000260
        000000000000001c  0000000000000000   A       5     0     8
   [ 5] .dynsym           DYNSYM           0000000000400280  00000280
        0000000000000060  0000000000000018   A       6     1     8
   [ 6] .dynstr           STRTAB           00000000004002e0  000002e0
        000000000000003d  0000000000000000   A       0     0     1
   [ 7] .gnu.version      VERSYM           000000000040031e  0000031e
        0000000000000008  0000000000000002   A       5     0     2
   [ 8] .gnu.version_r    VERNEED          0000000000400328  00000328
        0000000000000020  0000000000000000   A       6     1     8
   [ 9] .rela.dyn         RELA             0000000000400348  00000348
        0000000000000018  0000000000000018   A       5     0     8
   [10] .rela.plt         RELA             0000000000400360  00000360
        0000000000000030  0000000000000018   A       5    12     8
   [11] .init             PROGBITS         0000000000400390  00000390
        0000000000000018  0000000000000000  AX       0     0     4
   [12] .plt              PROGBITS         00000000004003a8  000003a8
        0000000000000030  0000000000000010  AX       0     0     4
   [13] .text             PROGBITS         00000000004003e0  000003e0
        00000000000001e8  0000000000000000  AX       0     0     16
   [14] .fini             PROGBITS         00000000004005c8  000005c8
        000000000000000e  0000000000000000  AX       0     0     4
   [15] .rodata           PROGBITS         00000000004005d8  000005d8
        000000000000001e  0000000000000000   A       0     0     8
   [16] .eh_frame_hdr     PROGBITS         00000000004005f8  000005f8
        0000000000000024  0000000000000000   A       0     0     4
   [17] .eh_frame         PROGBITS         0000000000400620  00000620
        000000000000007c  0000000000000000   A       0     0     8
   [18] .ctors            PROGBITS         00000000006006a0  000006a0
        0000000000000010  0000000000000000  WA       0     0     8
   [19] .dtors            PROGBITS         00000000006006b0  000006b0
        0000000000000010  0000000000000000  WA       0     0     8
   [20] .jcr              PROGBITS         00000000006006c0  000006c0
        0000000000000008  0000000000000000  WA       0     0     8
   [21] .dynamic          DYNAMIC          00000000006006c8  000006c8
        0000000000000190  0000000000000010  WA       6     0     8
   [22] .got              PROGBITS         0000000000600858  00000858
        0000000000000008  0000000000000008  WA       0     0     8
   [23] .got.plt          PROGBITS         0000000000600860  00000860
        0000000000000028  0000000000000008  WA       0     0     8
   [24] .data             PROGBITS         0000000000600888  00000888
        0000000000000004  0000000000000000  WA       0     0     4
   [25] .bss              NOBITS           0000000000600890  0000088c
        0000000000000010  0000000000000000  WA       0     0     8
   [26] .comment          PROGBITS         0000000000000000  0000088c
        000000000000002c  0000000000000001  MS       0     0     1
   [27] .shstrtab         STRTAB           0000000000000000  000008b8
        00000000000000fe  0000000000000000           0     0     1
   [28] .symtab           SYMTAB           0000000000000000  00001138
        0000000000000600  0000000000000018          29    46     8
   [29] .strtab           STRTAB           0000000000000000  00001738
        00000000000001f0  0000000000000000           0     0     1
 Key to Flags:
   W (write), A (alloc), X (execute), M (merge), S (strings)
   I (info), L (link order), G (group), x (unknown)
   O (extra OS processing required) o (OS specific), p (processor specific)

 There are no section groups in this file.

 Program Headers:
   Type           Offset             VirtAddr           PhysAddr
                  FileSiz            MemSiz              Flags  Align
   PHDR           0x0000000000000040 0x0000000000400040 0x0000000000400040
                  0x00000000000001c0 0x00000000000001c0  R E    8
   INTERP         0x0000000000000200 0x0000000000400200 0x0000000000400200
                  0x000000000000001c 0x000000000000001c  R      1
       [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
   LOAD           0x0000000000000000 0x0000000000400000 0x0000000000400000
                  0x000000000000069c 0x000000000000069c  R E    200000
   LOAD           0x00000000000006a0 0x00000000006006a0 0x00000000006006a0
                  0x00000000000001ec 0x0000000000000200  RW     200000
   DYNAMIC        0x00000000000006c8 0x00000000006006c8 0x00000000006006c8
                  0x0000000000000190 0x0000000000000190  RW     8
   NOTE           0x000000000000021c 0x000000000040021c 0x000000000040021c
                  0x0000000000000044 0x0000000000000044  R      4
   GNU_EH_FRAME   0x00000000000005f8 0x00000000004005f8 0x00000000004005f8
                  0x0000000000000024 0x0000000000000024  R      4
   GNU_STACK      0x0000000000000000 0x0000000000000000 0x0000000000000000
                  0x0000000000000000 0x0000000000000000  RW     8

  Section to Segment mapping:
   Segment Sections...
    00
    01     .interp
    02     .interp .note.ABI-tag .note.gnu.build-id .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn .rela.plt .init .plt .text .fini .rodata .eh_frame_hdr .eh_frame
    03     .ctors .dtors .jcr .dynamic .got .got.plt .data .bss
    04     .dynamic
    05     .note.ABI-tag .note.gnu.build-id
    06     .eh_frame_hdr
    07

 Dynamic section at offset 0x6c8 contains 20 entries:
   Tag        Type                         Name/Value
  0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
  0x000000000000000c (INIT)               0x400390
  0x000000000000000d (FINI)               0x4005c8
  0x000000006ffffef5 (GNU_HASH)           0x400260
  0x0000000000000005 (STRTAB)             0x4002e0
  0x0000000000000006 (SYMTAB)             0x400280
  0x000000000000000a (STRSZ)              61 (bytes)
  0x000000000000000b (SYMENT)             24 (bytes)
  0x0000000000000015 (DEBUG)              0x0
  0x0000000000000003 (PLTGOT)             0x600860
  0x0000000000000002 (PLTRELSZ)           48 (bytes)
  0x0000000000000014 (PLTREL)             RELA
  0x0000000000000017 (JMPREL)             0x400360
  0x0000000000000007 (RELA)               0x400348
  0x0000000000000008 (RELASZ)             24 (bytes)
  0x0000000000000009 (RELAENT)            24 (bytes)
  0x000000006ffffffe (VERNEED)            0x400328
  0x000000006fffffff (VERNEEDNUM)         1
  0x000000006ffffff0 (VERSYM)             0x40031e
  0x0000000000000000 (NULL)               0x0

 Relocation section '.rela.dyn' at offset 0x348 contains 1 entries:
   Offset          Info           Type           Sym. Value    Sym. Name + Addend
 000000600858  000100000006 R_X86_64_GLOB_DAT 0000000000000000 __gmon_start__ + 0

 Relocation section '.rela.plt' at offset 0x360 contains 2 entries:
   Offset          Info           Type           Sym. Value    Sym. Name + Addend
 000000600878  000200000007 R_X86_64_JUMP_SLO 0000000000000000 puts + 0
 000000600880  000300000007 R_X86_64_JUMP_SLO 0000000000000000 __libc_start_main + 0

 There are no unwind sections in this file.

 Symbol table '.dynsym' contains 4 entries:
    Num:    Value          Size Type    Bind   Vis      Ndx Name
      0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND
      1: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__
      2: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND puts@GLIBC_2.2.5 (2)
      3: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@GLIBC_2.2.5 (2)

 Symbol table '.symtab' contains 64 entries:
    Num:    Value          Size Type    Bind   Vis      Ndx Name
      0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND
      1: 0000000000400200     0 SECTION LOCAL  DEFAULT    1
      2: 000000000040021c     0 SECTION LOCAL  DEFAULT    2
      3: 000000000040023c     0 SECTION LOCAL  DEFAULT    3
      4: 0000000000400260     0 SECTION LOCAL  DEFAULT    4
      5: 0000000000400280     0 SECTION LOCAL  DEFAULT    5
      6: 00000000004002e0     0 SECTION LOCAL  DEFAULT    6
      7: 000000000040031e     0 SECTION LOCAL  DEFAULT    7
      8: 0000000000400328     0 SECTION LOCAL  DEFAULT    8
      9: 0000000000400348     0 SECTION LOCAL  DEFAULT    9
     10: 0000000000400360     0 SECTION LOCAL  DEFAULT   10
     11: 0000000000400390     0 SECTION LOCAL  DEFAULT   11
     12: 00000000004003a8     0 SECTION LOCAL  DEFAULT   12
     13: 00000000004003e0     0 SECTION LOCAL  DEFAULT   13
     14: 00000000004005c8     0 SECTION LOCAL  DEFAULT   14
     15: 00000000004005d8     0 SECTION LOCAL  DEFAULT   15
     16: 00000000004005f8     0 SECTION LOCAL  DEFAULT   16
     17: 0000000000400620     0 SECTION LOCAL  DEFAULT   17
     18: 00000000006006a0     0 SECTION LOCAL  DEFAULT   18
     19: 00000000006006b0     0 SECTION LOCAL  DEFAULT   19
     20: 00000000006006c0     0 SECTION LOCAL  DEFAULT   20
     21: 00000000006006c8     0 SECTION LOCAL  DEFAULT   21
     22: 0000000000600858     0 SECTION LOCAL  DEFAULT   22
     23: 0000000000600860     0 SECTION LOCAL  DEFAULT   23
     24: 0000000000600888     0 SECTION LOCAL  DEFAULT   24
     25: 0000000000600890     0 SECTION LOCAL  DEFAULT   25
     26: 0000000000000000     0 SECTION LOCAL  DEFAULT   26
     27: 000000000040040c     0 FUNC    LOCAL  DEFAULT   13 call_gmon_start
     28: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS crtstuff.c
     29: 00000000006006a0     0 OBJECT  LOCAL  DEFAULT   18 __CTOR_LIST__
     30: 00000000006006b0     0 OBJECT  LOCAL  DEFAULT   19 __DTOR_LIST__
     31: 00000000006006c0     0 OBJECT  LOCAL  DEFAULT   20 __JCR_LIST__
     32: 0000000000400430     0 FUNC    LOCAL  DEFAULT   13 __do_global_dtors_aux
     33: 0000000000600890     1 OBJECT  LOCAL  DEFAULT   25 completed.6349
     34: 0000000000600898     8 OBJECT  LOCAL  DEFAULT   25 dtor_idx.6351
     35: 00000000004004a0     0 FUNC    LOCAL  DEFAULT   13 frame_dummy
     36: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS crtstuff.c
     37: 00000000006006a8     0 OBJECT  LOCAL  DEFAULT   18 __CTOR_END__
     38: 0000000000400698     0 OBJECT  LOCAL  DEFAULT   17 __FRAME_END__
     39: 00000000006006c0     0 OBJECT  LOCAL  DEFAULT   20 __JCR_END__
     40: 0000000000400590     0 FUNC    LOCAL  DEFAULT   13 __do_global_ctors_aux
     41: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS main.c
     42: 0000000000600860     0 OBJECT  LOCAL  DEFAULT   23 _GLOBAL_OFFSET_TABLE_
     43: 000000000060069c     0 NOTYPE  LOCAL  DEFAULT   18 __init_array_end
     44: 000000000060069c     0 NOTYPE  LOCAL  DEFAULT   18 __init_array_start
     45: 00000000006006c8     0 OBJECT  LOCAL  DEFAULT   21 _DYNAMIC
     46: 0000000000600888     0 NOTYPE  WEAK   DEFAULT   24 data_start
     47: 00000000004004f0     2 FUNC    GLOBAL DEFAULT   13 __libc_csu_fini
     48: 00000000004003e0     0 FUNC    GLOBAL DEFAULT   13 _start
     49: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__
     50: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _Jv_RegisterClasses
     51: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND puts@@GLIBC_2.2.5
     52: 00000000004005c8     0 FUNC    GLOBAL DEFAULT   14 _fini
     53: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@@GLIBC_
     54: 00000000004005d8     4 OBJECT  GLOBAL DEFAULT   15 _IO_stdin_used
     55: 0000000000600888     0 NOTYPE  GLOBAL DEFAULT   24 __data_start
     56: 00000000004005e0     0 OBJECT  GLOBAL HIDDEN    15 __dso_handle
     57: 00000000006006b8     0 OBJECT  GLOBAL HIDDEN    19 __DTOR_END__
     58: 0000000000400500   137 FUNC    GLOBAL DEFAULT   13 __libc_csu_init
     59: 000000000060088c     0 NOTYPE  GLOBAL DEFAULT  ABS __bss_start
     60: 00000000006008a0     0 NOTYPE  GLOBAL DEFAULT  ABS _end
     61: 000000000060088c     0 NOTYPE  GLOBAL DEFAULT  ABS _edata
     62: 00000000004004c4    32 FUNC    GLOBAL DEFAULT   13 main
     63: 0000000000400390     0 FUNC    GLOBAL DEFAULT   11 _init

 Version symbols section '.gnu.version' contains 4 entries:
  Addr: 000000000040031e  Offset: 0x00031e  Link: 5 (.dynsym)
   000:   0 (*local*)       0 (*local*)       2 (GLIBC_2.2.5)   2 (GLIBC_2.2.5)

 Version needs section '.gnu.version_r' contains 1 entries:
  Addr: 0x0000000000400328  Offset: 0x000328  Link: 6 (.dynstr)
   000000: Version: 1  File: libc.so.6  Cnt: 1
   0x0010:   Name: GLIBC_2.2.5  Flags: none  Version: 2

 Notes at offset 0x0000021c with length 0x00000020:
   Owner		Data size	Description
   GNU		0x00000010	NT_GNU_ABI_TAG (ABI version tag)

 Notes at offset 0x0000023c with length 0x00000024:
   Owner		Data size	Description
   GNU		0x00000014	NT_GNU_BUILD_ID (unique build ID bitstring)
```
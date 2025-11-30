# CS-FEC 软件驱动

## 概述

本目录包含 CS-FEC 硬件加速器的软件驱动和示例代码。

## 文件说明

| 文件 | 说明 |
|------|------|
| `cs_fec_driver.h` | 驱动头文件 - 寄存器定义和 API 声明 |
| `cs_fec_driver.c` | 驱动实现 |
| `example_linux.c` | Linux 用户空间示例 |
| `example_baremetal.c` | 裸机 (Vitis) 示例 |

## 硬件寄存器映射

```
偏移地址    名称          描述
─────────────────────────────────────────
0x00       CTRL         控制寄存器
                        [0]: enc_start - 启动编码
                        [1]: dec_start - 启动解码
                        [31]: busy - 忙标志 (只读)

0x04       STATUS       状态寄存器
                        [0]: enc_done - 编码完成
                        [1]: dec_done - 解码完成
                        [2]: dec_ok - 解码成功

0x08       CONFIG       配置寄存器
                        [K-1:0]: erasure_mask - 丢失标记

0x10-0x1C  DATA_IN[0-3] 编码输入数据 (M 个符号)

0x20-0x3C  CODED[0-7]   编码输出 / 解码输入 (K 个符号)

0x40-0x4C  DATA_OUT[0-3] 解码输出数据 (M 个符号)
```

## 使用流程

### 编码流程

```c
// 1. 写入原始数据
for (i = 0; i < M; i++)
    write(DATA_IN[i], data[i]);

// 2. 启动编码
write(CTRL, 0x1);

// 3. 等待完成
while (!(read(STATUS) & ENC_DONE));

// 4. 读取编码结果
for (i = 0; i < K; i++)
    coded[i] = read(CODED[i]);

// 5. 清除启动位
write(CTRL, 0x0);
```

### 解码流程

```c
// 1. 写入编码数据
for (i = 0; i < K; i++)
    write(CODED[i], coded[i]);

// 2. 设置丢失掩码 (例如: bit 0 = 1 表示符号 0 丢失)
write(CONFIG, erasure_mask);

// 3. 启动解码
write(CTRL, 0x2);

// 4. 等待完成
while (!(read(STATUS) & DEC_DONE));

// 5. 检查解码是否成功
if (read(STATUS) & DEC_OK) {
    // 读取恢复的数据
    for (i = 0; i < M; i++)
        data[i] = read(DATA_OUT[i]);
}

// 6. 清除启动位
write(CTRL, 0x0);
```

## Linux 环境

### 方式 1: /dev/mem (需要 root)

```bash
gcc -o cs_fec_test example_linux.c cs_fec_driver.c
sudo ./cs_fec_test
```

### 方式 2: UIO 驱动 (推荐)

1. 在设备树中添加:
```dts
cs_fec: cs_fec@80000000 {
    compatible = "generic-uio";
    reg = <0x0 0x80000000 0x0 0x1000>;
};
```

2. 代码中使用 `/dev/uio0`:
```c
fd = open("/dev/uio0", O_RDWR);
map_base = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
```

## Vitis 裸机环境

1. 在 Vitis 中创建新的 Application Project
2. 选择生成的 XSA 文件
3. 将 `cs_fec_driver.c/h` 和 `example_baremetal.c` 添加到工程
4. 修改 `CS_FEC_BASE_ADDR` 为实际地址 (查看 xparameters.h)
5. 编译并运行

## API 参考

```c
// 初始化
int cs_fec_init(cs_fec_t *dev, void *base_addr, 
                uint32_t m, uint32_t k, uint32_t width);

// 编码: data_in[M] -> coded_out[K]
int cs_fec_encode(cs_fec_t *dev, const uint32_t *data_in, uint32_t *coded_out);

// 解码: coded_in[K] + erasure_mask -> data_out[M]
int cs_fec_decode(cs_fec_t *dev, const uint32_t *coded_in, 
                  uint32_t erasure_mask, uint32_t *data_out);
```

## 性能

- 编码延迟: ~2 时钟周期
- 解码延迟: ~3 时钟周期
- 时钟频率: 200 MHz (典型)
- 吞吐量: ~100 M 符号/秒


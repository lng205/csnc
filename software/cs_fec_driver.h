/**
 * @file cs_fec_driver.h
 * @brief CS-FEC 硬件加速器驱动头文件
 * 
 * 支持两种访问方式:
 * 1. Linux UIO (用户空间 I/O)
 * 2. 裸机 (Bare-metal) 直接访问
 */

#ifndef CS_FEC_DRIVER_H
#define CS_FEC_DRIVER_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

//-----------------------------------------------------------------------------
// 寄存器偏移定义
//-----------------------------------------------------------------------------
#define CS_FEC_REG_CTRL      0x00   // 控制寄存器
#define CS_FEC_REG_STATUS    0x04   // 状态寄存器
#define CS_FEC_REG_CONFIG    0x08   // 配置寄存器 (erasure mask)
#define CS_FEC_REG_DATA_IN   0x10   // 编码输入数据 (0x10-0x1C)
#define CS_FEC_REG_CODED     0x20   // 编码输出/解码输入 (0x20-0x3C)
#define CS_FEC_REG_DATA_OUT  0x40   // 解码输出数据 (0x40-0x4C)

// 控制寄存器位定义
#define CS_FEC_CTRL_ENC_START  (1 << 0)
#define CS_FEC_CTRL_DEC_START  (1 << 1)

// 状态寄存器位定义
#define CS_FEC_STATUS_ENC_DONE (1 << 0)
#define CS_FEC_STATUS_DEC_DONE (1 << 1)
#define CS_FEC_STATUS_DEC_OK   (1 << 2)
#define CS_FEC_STATUS_BUSY     (1 << 31)

//-----------------------------------------------------------------------------
// 配置参数 (与 RTL 匹配)
//-----------------------------------------------------------------------------
#define CS_FEC_MAX_M    4    // 最大数据符号数
#define CS_FEC_MAX_K    8    // 最大总符号数

//-----------------------------------------------------------------------------
// 驱动结构体
//-----------------------------------------------------------------------------
typedef struct {
    volatile uint32_t *base_addr;  // 寄存器基地址
    uint32_t m;                    // 数据符号数
    uint32_t k;                    // 总符号数
    uint32_t width;                // 符号位宽
} cs_fec_t;

//-----------------------------------------------------------------------------
// 初始化和清理
//-----------------------------------------------------------------------------

/**
 * @brief 初始化 CS-FEC 驱动
 * @param dev 设备结构体指针
 * @param base_addr 寄存器基地址
 * @param m 数据符号数
 * @param k 总符号数
 * @param width 符号位宽
 * @return 0 成功, -1 失败
 */
int cs_fec_init(cs_fec_t *dev, void *base_addr, uint32_t m, uint32_t k, uint32_t width);

/**
 * @brief 复位加速器
 * @param dev 设备结构体指针
 */
void cs_fec_reset(cs_fec_t *dev);

//-----------------------------------------------------------------------------
// 编码操作
//-----------------------------------------------------------------------------

/**
 * @brief 执行编码操作
 * @param dev 设备结构体指针
 * @param data_in 输入数据数组 (M 个符号)
 * @param coded_out 输出数据数组 (K 个符号)
 * @return 0 成功, -1 失败
 */
int cs_fec_encode(cs_fec_t *dev, const uint32_t *data_in, uint32_t *coded_out);

//-----------------------------------------------------------------------------
// 解码操作
//-----------------------------------------------------------------------------

/**
 * @brief 执行解码操作
 * @param dev 设备结构体指针
 * @param coded_in 输入编码数据数组 (K 个符号)
 * @param erasure_mask 丢失标记位掩码 (bit i=1 表示符号 i 丢失)
 * @param data_out 输出解码数据数组 (M 个符号)
 * @return 0 成功, -1 解码失败 (丢失过多)
 */
int cs_fec_decode(cs_fec_t *dev, const uint32_t *coded_in, uint32_t erasure_mask, uint32_t *data_out);

//-----------------------------------------------------------------------------
// 底层寄存器访问
//-----------------------------------------------------------------------------

static inline void cs_fec_write_reg(cs_fec_t *dev, uint32_t offset, uint32_t value) {
    dev->base_addr[offset / 4] = value;
}

static inline uint32_t cs_fec_read_reg(cs_fec_t *dev, uint32_t offset) {
    return dev->base_addr[offset / 4];
}

static inline bool cs_fec_is_busy(cs_fec_t *dev) {
    return (cs_fec_read_reg(dev, CS_FEC_REG_STATUS) & CS_FEC_STATUS_BUSY) != 0;
}

#ifdef __cplusplus
}
#endif

#endif // CS_FEC_DRIVER_H


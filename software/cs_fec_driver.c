/**
 * @file cs_fec_driver.c
 * @brief CS-FEC 硬件加速器驱动实现
 */

#include "cs_fec_driver.h"
#include <string.h>

// 超时计数
#define CS_FEC_TIMEOUT 10000

int cs_fec_init(cs_fec_t *dev, void *base_addr, uint32_t m, uint32_t k, uint32_t width) {
    if (!dev || !base_addr) return -1;
    if (m > CS_FEC_MAX_M || k > CS_FEC_MAX_K || m >= k) return -1;
    
    dev->base_addr = (volatile uint32_t *)base_addr;
    dev->m = m;
    dev->k = k;
    dev->width = width;
    
    // 复位
    cs_fec_reset(dev);
    
    return 0;
}

void cs_fec_reset(cs_fec_t *dev) {
    if (!dev) return;
    
    // 清除控制寄存器
    cs_fec_write_reg(dev, CS_FEC_REG_CTRL, 0);
    cs_fec_write_reg(dev, CS_FEC_REG_CONFIG, 0);
}

int cs_fec_encode(cs_fec_t *dev, const uint32_t *data_in, uint32_t *coded_out) {
    if (!dev || !data_in || !coded_out) return -1;
    
    uint32_t timeout = CS_FEC_TIMEOUT;
    
    // 等待空闲
    while (cs_fec_is_busy(dev) && timeout--);
    if (timeout == 0) return -1;
    
    // 写入输入数据
    for (uint32_t i = 0; i < dev->m; i++) {
        cs_fec_write_reg(dev, CS_FEC_REG_DATA_IN + i * 4, data_in[i]);
    }
    
    // 启动编码
    cs_fec_write_reg(dev, CS_FEC_REG_CTRL, CS_FEC_CTRL_ENC_START);
    
    // 等待完成
    timeout = CS_FEC_TIMEOUT;
    while (!(cs_fec_read_reg(dev, CS_FEC_REG_STATUS) & CS_FEC_STATUS_ENC_DONE) && timeout--);
    if (timeout == 0) {
        cs_fec_write_reg(dev, CS_FEC_REG_CTRL, 0);
        return -1;
    }
    
    // 读取输出
    for (uint32_t i = 0; i < dev->k; i++) {
        coded_out[i] = cs_fec_read_reg(dev, CS_FEC_REG_CODED + i * 4);
    }
    
    // 清除启动位
    cs_fec_write_reg(dev, CS_FEC_REG_CTRL, 0);
    
    return 0;
}

int cs_fec_decode(cs_fec_t *dev, const uint32_t *coded_in, uint32_t erasure_mask, uint32_t *data_out) {
    if (!dev || !coded_in || !data_out) return -1;
    
    uint32_t timeout = CS_FEC_TIMEOUT;
    
    // 等待空闲
    while (cs_fec_is_busy(dev) && timeout--);
    if (timeout == 0) return -1;
    
    // 写入编码数据
    for (uint32_t i = 0; i < dev->k; i++) {
        cs_fec_write_reg(dev, CS_FEC_REG_CODED + i * 4, coded_in[i]);
    }
    
    // 设置丢失掩码
    cs_fec_write_reg(dev, CS_FEC_REG_CONFIG, erasure_mask);
    
    // 启动解码
    cs_fec_write_reg(dev, CS_FEC_REG_CTRL, CS_FEC_CTRL_DEC_START);
    
    // 等待完成
    timeout = CS_FEC_TIMEOUT;
    while (!(cs_fec_read_reg(dev, CS_FEC_REG_STATUS) & CS_FEC_STATUS_DEC_DONE) && timeout--);
    if (timeout == 0) {
        cs_fec_write_reg(dev, CS_FEC_REG_CTRL, 0);
        return -1;
    }
    
    // 检查解码是否成功
    uint32_t status = cs_fec_read_reg(dev, CS_FEC_REG_STATUS);
    if (!(status & CS_FEC_STATUS_DEC_OK)) {
        cs_fec_write_reg(dev, CS_FEC_REG_CTRL, 0);
        return -1;  // 丢失过多，无法恢复
    }
    
    // 读取输出
    for (uint32_t i = 0; i < dev->m; i++) {
        data_out[i] = cs_fec_read_reg(dev, CS_FEC_REG_DATA_OUT + i * 4);
    }
    
    // 清除启动位
    cs_fec_write_reg(dev, CS_FEC_REG_CTRL, 0);
    
    return 0;
}


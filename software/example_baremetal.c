/**
 * @file example_baremetal.c
 * @brief 裸机 (Bare-metal) 环境使用 CS-FEC 加速器的示例
 *        适用于 Vitis 开发环境
 */

#include <stdio.h>
#include "xparameters.h"  // Vitis 生成的地址定义
#include "cs_fec_driver.h"

// 如果使用 Vitis 自动生成的地址定义:
// #define CS_FEC_BASE_ADDR XPAR_CS_CODEC_AXI_0_BASEADDR
// 否则手动定义:
#define CS_FEC_BASE_ADDR  0x80000000

int main() {
    cs_fec_t dev;
    
    // (2, 3) 配置
    const uint32_t M = 2;
    const uint32_t K = 3;
    const uint32_t WIDTH = 4;
    
    printf("\n=== CS-FEC Baremetal Test ===\n\n");
    
    // 初始化
    if (cs_fec_init(&dev, (void *)CS_FEC_BASE_ADDR, M, K, WIDTH) != 0) {
        printf("Init failed!\n");
        return -1;
    }
    
    // 测试数据
    uint32_t data[2] = {0xA, 0x5};
    uint32_t coded[3] = {0};
    uint32_t recovered[2] = {0};
    
    // 编码
    printf("Original: [0x%X, 0x%X]\n", data[0], data[1]);
    
    if (cs_fec_encode(&dev, data, coded) == 0) {
        printf("Encoded:  [0x%X, 0x%X, 0x%X]\n", coded[0], coded[1], coded[2]);
    }
    
    // 模拟丢失并解码
    coded[0] = 0;  // D0 丢失
    
    if (cs_fec_decode(&dev, coded, 0x1, recovered) == 0) {
        printf("Recovered: [0x%X, 0x%X]\n", recovered[0], recovered[1]);
        
        if (recovered[0] == data[0] && recovered[1] == data[1]) {
            printf("\n*** TEST PASSED ***\n");
        } else {
            printf("\n*** TEST FAILED ***\n");
        }
    }
    
    return 0;
}


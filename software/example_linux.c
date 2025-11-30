/**
 * @file example_linux.c
 * @brief Linux 用户空间使用 CS-FEC 加速器的示例
 * 
 * 编译: gcc -o cs_fec_test example_linux.c cs_fec_driver.c
 * 运行: sudo ./cs_fec_test
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "cs_fec_driver.h"

// CS-FEC 加速器基地址 (从 Vivado Address Editor 获取)
// 需要根据实际硬件设计修改
#define CS_FEC_BASE_ADDR  0x80000000
#define CS_FEC_SIZE       0x1000

int main(int argc, char *argv[]) {
    int fd;
    void *map_base;
    cs_fec_t dev;
    
    // (2, 3) 配置: 2 个数据, 3 个编码, 4-bit 符号
    const uint32_t M = 2;
    const uint32_t K = 3;
    const uint32_t WIDTH = 4;
    
    printf("===================================\n");
    printf("  CS-FEC Hardware Accelerator Test\n");
    printf("===================================\n\n");
    
    //-------------------------------------------------------------------------
    // 1. 打开 /dev/mem 并映射物理地址
    //-------------------------------------------------------------------------
    fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("open /dev/mem failed");
        printf("请使用 sudo 运行，或使用 UIO 驱动\n");
        return -1;
    }
    
    map_base = mmap(NULL, CS_FEC_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED,
                    fd, CS_FEC_BASE_ADDR);
    if (map_base == MAP_FAILED) {
        perror("mmap failed");
        close(fd);
        return -1;
    }
    
    printf("[1] Memory mapped at %p (phys: 0x%08X)\n\n", map_base, CS_FEC_BASE_ADDR);
    
    //-------------------------------------------------------------------------
    // 2. 初始化驱动
    //-------------------------------------------------------------------------
    if (cs_fec_init(&dev, map_base, M, K, WIDTH) != 0) {
        printf("ERROR: cs_fec_init failed\n");
        goto cleanup;
    }
    printf("[2] Driver initialized: M=%d, K=%d, WIDTH=%d\n\n", M, K, WIDTH);
    
    //-------------------------------------------------------------------------
    // 3. 编码测试
    //-------------------------------------------------------------------------
    uint32_t data_in[M] = {0xA, 0x5};  // 原始数据
    uint32_t coded[K] = {0};            // 编码结果
    
    printf("[3] Encoding test:\n");
    printf("    Input: ");
    for (uint32_t i = 0; i < M; i++) printf("0x%X ", data_in[i]);
    printf("\n");
    
    if (cs_fec_encode(&dev, data_in, coded) != 0) {
        printf("ERROR: Encoding failed\n");
        goto cleanup;
    }
    
    printf("    Coded: ");
    for (uint32_t i = 0; i < K; i++) printf("0x%X ", coded[i]);
    printf("\n\n");
    
    //-------------------------------------------------------------------------
    // 4. 解码测试 - 无丢失
    //-------------------------------------------------------------------------
    uint32_t data_out[M] = {0};
    
    printf("[4] Decoding test (no erasure):\n");
    
    if (cs_fec_decode(&dev, coded, 0x0, data_out) != 0) {
        printf("ERROR: Decoding failed\n");
        goto cleanup;
    }
    
    printf("    Output: ");
    for (uint32_t i = 0; i < M; i++) printf("0x%X ", data_out[i]);
    printf("\n");
    printf("    Result: %s\n\n", 
           (data_out[0] == data_in[0] && data_out[1] == data_in[1]) ? "PASS" : "FAIL");
    
    //-------------------------------------------------------------------------
    // 5. 解码测试 - D0 丢失
    //-------------------------------------------------------------------------
    printf("[5] Decoding test (D0 erased):\n");
    
    uint32_t coded_erased[K];
    for (uint32_t i = 0; i < K; i++) coded_erased[i] = coded[i];
    coded_erased[0] = 0;  // 模拟 D0 丢失
    
    if (cs_fec_decode(&dev, coded_erased, 0x1, data_out) != 0) {  // erasure mask: bit 0 = 1
        printf("ERROR: Decoding failed\n");
        goto cleanup;
    }
    
    printf("    Coded (erased): ");
    for (uint32_t i = 0; i < K; i++) printf("0x%X ", coded_erased[i]);
    printf("\n");
    printf("    Recovered: ");
    for (uint32_t i = 0; i < M; i++) printf("0x%X ", data_out[i]);
    printf("\n");
    printf("    Result: %s\n\n", 
           (data_out[0] == data_in[0] && data_out[1] == data_in[1]) ? "PASS ✓" : "FAIL");
    
    //-------------------------------------------------------------------------
    // 6. 解码测试 - D1 丢失
    //-------------------------------------------------------------------------
    printf("[6] Decoding test (D1 erased):\n");
    
    for (uint32_t i = 0; i < K; i++) coded_erased[i] = coded[i];
    coded_erased[1] = 0;  // 模拟 D1 丢失
    
    if (cs_fec_decode(&dev, coded_erased, 0x2, data_out) != 0) {  // erasure mask: bit 1 = 1
        printf("ERROR: Decoding failed\n");
        goto cleanup;
    }
    
    printf("    Coded (erased): ");
    for (uint32_t i = 0; i < K; i++) printf("0x%X ", coded_erased[i]);
    printf("\n");
    printf("    Recovered: ");
    for (uint32_t i = 0; i < M; i++) printf("0x%X ", data_out[i]);
    printf("\n");
    printf("    Result: %s\n\n", 
           (data_out[0] == data_in[0] && data_out[1] == data_in[1]) ? "PASS ✓" : "FAIL");
    
    printf("===================================\n");
    printf("  All tests completed!\n");
    printf("===================================\n");

cleanup:
    munmap(map_base, CS_FEC_SIZE);
    close(fd);
    return 0;
}


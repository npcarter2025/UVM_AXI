/*
 * DPI-C Memory Model for AXI Scoreboard
 * 
 * This C/C++ implementation provides an alternative memory model that can be
 * used instead of the SystemVerilog model in the scoreboard.
 * 
 * To use: Compile with USE_DPI_MODEL=1 and set use_dpi_model=1 in config_db
 */

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <string.h>

#define MEM_SIZE 1024

// Memory model state
static uint32_t memory_model[MEM_SIZE];
static uint32_t mem_size_reg_model = 1024;
static uint32_t write_count_reg_model = 0;
static uint32_t read_count_reg_model = 0;

/**
 * Initialize the memory model
 * Sets all memory to zero and resets registers to default values
 */
void c_memory_model_init() {
    memset(memory_model, 0, sizeof(memory_model));
    mem_size_reg_model = 1024;
    write_count_reg_model = 0;
    read_count_reg_model = 0;
}

/**
 * Handle write transaction
 * Updates memory or registers based on address
 * 
 * @param addr: 32-bit address (byte address)
 * @param data: 32-bit data to write
 */
void c_memory_model_write(uint32_t addr, uint32_t data) {
    if (addr == 0x0000) {
        // MEM_SIZE_REG
        mem_size_reg_model = data;
    } else {
        // Memory addresses - convert byte address to word index (bits [11:2])
        // addr[11:2] extracts the word-aligned index
        uint32_t word_idx = (addr >> 2) & 0x3FF;
        
        if (word_idx < mem_size_reg_model && word_idx < MEM_SIZE) {
            memory_model[word_idx] = data;
        }
    }
}

/**
 * Get expected read data for a given address
 * 
 * @param addr: 32-bit address (byte address)
 * @return: 32-bit expected data value
 *          Returns 0xFFFFFFFF for FIFO_STATUS_REG (skip check flag)
 */
uint32_t c_memory_model_read(uint32_t addr) {
    if (addr == 0x0000) {
        // MEM_SIZE_REG
        return mem_size_reg_model;
    } else if (addr == 0x0004) {
        // FIFO_STATUS_REG - cannot predict, return special value to skip check
        return 0xFFFFFFFF;  // Special flag to skip comparison
    } else if (addr == 0x0008) {
        // WRITE_COUNT_REG
        return write_count_reg_model;
    } else if (addr == 0x000C) {
        // READ_COUNT_REG - increment after read
        uint32_t val = read_count_reg_model;
        read_count_reg_model++;
        return val;
    } else {
        // Memory read - convert byte address to word index (bits [11:2])
        uint32_t word_idx = (addr >> 2) & 0x3FF;
        
        if (word_idx < mem_size_reg_model && word_idx < MEM_SIZE) {
            return memory_model[word_idx];
        } else {
            // Invalid address
            return 0xDEADBEEF;
        }
    }
}

#ifdef __cplusplus
}
#endif

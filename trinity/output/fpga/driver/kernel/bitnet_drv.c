// SPDX-License-Identifier: GPL-2.0
/*
 * VIBEE BitNet Accelerator Linux Driver
 *
 * Platform driver для управления BitNet акселератором на Zynq UltraScale+
 *
 * Священная Формула: V = n × 3^k × π^m × φ^p × e^q
 * Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
 *
 * Copyright (c) 2024 VIBEE Project
 */

#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/of_address.h>
#include <linux/of_irq.h>
#include <linux/of_reserved_mem.h>
#include <linux/io.h>
#include <linux/interrupt.h>
#include <linux/dma-mapping.h>
#include <linux/dmaengine.h>
#include <linux/cdev.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/wait.h>
#include <linux/poll.h>
#include <linux/mutex.h>
#include <linux/completion.h>

#include "bitnet_drv.h"

#define DRIVER_NAME     "bitnet"
#define DRIVER_VERSION  "1.0.0"
#define MAX_DEVICES     4

/* ═══════════════════════════════════════════════════════════════════════════
 * Глобальные переменные
 * ═══════════════════════════════════════════════════════════════════════════ */

static dev_t bitnet_devt;
static struct class *bitnet_class;
static int bitnet_major;
static DEFINE_IDA(bitnet_ida);

/* ═══════════════════════════════════════════════════════════════════════════
 * Структура устройства
 * ═══════════════════════════════════════════════════════════════════════════ */

struct bitnet_dev {
    struct device *dev;
    struct cdev cdev;
    int minor;
    
    /* Memory-mapped registers */
    void __iomem *regs;
    resource_size_t regs_phys;
    resource_size_t regs_size;
    
    /* DMA */
    struct dma_chan *dma_input;
    struct dma_chan *dma_output;
    struct dma_chan *dma_weights;
    
    /* DMA buffers */
    void *input_buf;
    dma_addr_t input_dma;
    size_t input_size;
    
    void *output_buf;
    dma_addr_t output_dma;
    size_t output_size;
    
    void *weight_buf;
    dma_addr_t weight_dma;
    size_t weight_size;
    
    /* Combined mmap buffer */
    void *mmap_buf;
    dma_addr_t mmap_dma;
    size_t mmap_size;
    
    /* IRQ */
    int irq;
    
    /* State */
    enum bitnet_state state;
    struct mutex lock;
    struct completion inference_done;
    wait_queue_head_t wait_queue;
    
    /* Statistics */
    u64 inference_count;
    u64 total_cycles;
    u32 last_error;
};

/* ═══════════════════════════════════════════════════════════════════════════
 * Register access helpers
 * ═══════════════════════════════════════════════════════════════════════════ */

static inline u32 bitnet_read(struct bitnet_dev *dev, u32 offset)
{
    return ioread32(dev->regs + offset);
}

static inline void bitnet_write(struct bitnet_dev *dev, u32 offset, u32 value)
{
    iowrite32(value, dev->regs + offset);
}

static inline void bitnet_set_bits(struct bitnet_dev *dev, u32 offset, u32 bits)
{
    u32 val = bitnet_read(dev, offset);
    bitnet_write(dev, offset, val | bits);
}

static inline void bitnet_clear_bits(struct bitnet_dev *dev, u32 offset, u32 bits)
{
    u32 val = bitnet_read(dev, offset);
    bitnet_write(dev, offset, val & ~bits);
}

/* ═══════════════════════════════════════════════════════════════════════════
 * Hardware control
 * ═══════════════════════════════════════════════════════════════════════════ */

static int bitnet_hw_reset(struct bitnet_dev *dev)
{
    /* Assert reset */
    bitnet_set_bits(dev, BITNET_REG_CTRL, BITNET_CTRL_RESET);
    
    /* Wait for reset to complete */
    usleep_range(100, 200);
    
    /* Deassert reset */
    bitnet_clear_bits(dev, BITNET_REG_CTRL, BITNET_CTRL_RESET);
    
    /* Wait for ready */
    usleep_range(100, 200);
    
    /* Check status */
    u32 status = bitnet_read(dev, BITNET_REG_STATUS);
    if (status & BITNET_STATUS_ERROR) {
        dev_err(dev->dev, "Hardware error after reset: 0x%08x\n", status);
        return -EIO;
    }
    
    dev->state = BITNET_STATE_IDLE;
    return 0;
}

static int bitnet_hw_start_inference(struct bitnet_dev *dev)
{
    /* Check if idle */
    u32 status = bitnet_read(dev, BITNET_REG_STATUS);
    if (status & BITNET_STATUS_BUSY) {
        dev_warn(dev->dev, "Accelerator busy\n");
        return -EBUSY;
    }
    
    /* Enable IRQ */
    bitnet_set_bits(dev, BITNET_REG_CTRL, BITNET_CTRL_IRQ_EN);
    
    /* Start inference */
    bitnet_set_bits(dev, BITNET_REG_CTRL, BITNET_CTRL_START);
    
    dev->state = BITNET_STATE_RUNNING;
    return 0;
}

static void bitnet_hw_abort(struct bitnet_dev *dev)
{
    bitnet_set_bits(dev, BITNET_REG_CTRL, BITNET_CTRL_ABORT);
    dev->state = BITNET_STATE_IDLE;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * IRQ handler
 * ═══════════════════════════════════════════════════════════════════════════ */

static irqreturn_t bitnet_irq_handler(int irq, void *data)
{
    struct bitnet_dev *dev = data;
    u32 status;
    
    status = bitnet_read(dev, BITNET_REG_STATUS);
    
    /* Clear IRQ */
    bitnet_clear_bits(dev, BITNET_REG_CTRL, BITNET_CTRL_IRQ_EN);
    bitnet_clear_bits(dev, BITNET_REG_CTRL, BITNET_CTRL_START);
    
    if (status & BITNET_STATUS_DONE) {
        dev->inference_count++;
        dev->total_cycles += bitnet_read(dev, BITNET_REG_CYCLE_COUNT);
        dev->state = BITNET_STATE_IDLE;
        complete(&dev->inference_done);
        wake_up_interruptible(&dev->wait_queue);
    }
    
    if (status & BITNET_STATUS_ERROR) {
        dev->last_error = bitnet_read(dev, BITNET_REG_ERROR_CODE);
        dev->state = BITNET_STATE_ERROR;
        dev_err(dev->dev, "Hardware error: 0x%08x\n", dev->last_error);
        complete(&dev->inference_done);
        wake_up_interruptible(&dev->wait_queue);
    }
    
    return IRQ_HANDLED;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * DMA operations
 * ═══════════════════════════════════════════════════════════════════════════ */

static void bitnet_dma_callback(void *data)
{
    struct completion *done = data;
    complete(done);
}

static int bitnet_dma_transfer(struct bitnet_dev *dev, 
                               struct dma_chan *chan,
                               dma_addr_t src, dma_addr_t dst,
                               size_t len, bool to_device)
{
    struct dma_async_tx_descriptor *desc;
    struct completion done;
    enum dma_transfer_direction dir;
    dma_cookie_t cookie;
    int ret;
    
    init_completion(&done);
    
    dir = to_device ? DMA_MEM_TO_DEV : DMA_DEV_TO_MEM;
    
    desc = dmaengine_prep_slave_single(chan, 
                                       to_device ? src : dst,
                                       len, dir,
                                       DMA_PREP_INTERRUPT | DMA_CTRL_ACK);
    if (!desc) {
        dev_err(dev->dev, "Failed to prepare DMA descriptor\n");
        return -ENOMEM;
    }
    
    desc->callback = bitnet_dma_callback;
    desc->callback_param = &done;
    
    cookie = dmaengine_submit(desc);
    if (dma_submit_error(cookie)) {
        dev_err(dev->dev, "Failed to submit DMA\n");
        return -EIO;
    }
    
    dma_async_issue_pending(chan);
    
    /* Wait for completion with timeout */
    ret = wait_for_completion_timeout(&done, msecs_to_jiffies(DMA_TIMEOUT_MS));
    if (ret == 0) {
        dev_err(dev->dev, "DMA timeout\n");
        dmaengine_terminate_all(chan);
        return -ETIMEDOUT;
    }
    
    return 0;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * File operations
 * ═══════════════════════════════════════════════════════════════════════════ */

static int bitnet_open(struct inode *inode, struct file *file)
{
    struct bitnet_dev *dev;
    
    dev = container_of(inode->i_cdev, struct bitnet_dev, cdev);
    file->private_data = dev;
    
    return 0;
}

static int bitnet_release(struct inode *inode, struct file *file)
{
    struct bitnet_dev *dev = file->private_data;
    
    /* Abort any running inference */
    if (dev->state == BITNET_STATE_RUNNING) {
        bitnet_hw_abort(dev);
    }
    
    return 0;
}

static int bitnet_mmap(struct file *file, struct vm_area_struct *vma)
{
    struct bitnet_dev *dev = file->private_data;
    unsigned long size = vma->vm_end - vma->vm_start;
    
    if (size > dev->mmap_size) {
        dev_err(dev->dev, "mmap size too large: %lu > %zu\n", 
                size, dev->mmap_size);
        return -EINVAL;
    }
    
    /* Map DMA coherent memory to userspace */
    return dma_mmap_coherent(dev->dev, vma, dev->mmap_buf,
                             dev->mmap_dma, size);
}

static long bitnet_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
    struct bitnet_dev *dev = file->private_data;
    void __user *argp = (void __user *)arg;
    int ret = 0;
    
    if (mutex_lock_interruptible(&dev->lock))
        return -ERESTARTSYS;
    
    switch (cmd) {
    case BITNET_IOC_START_INFERENCE: {
        struct bitnet_inference_req req;
        
        if (copy_from_user(&req, argp, sizeof(req))) {
            ret = -EFAULT;
            break;
        }
        
        /* Validate offsets */
        if (req.input_offset + req.input_size > dev->mmap_size ||
            req.output_offset + req.output_size > dev->mmap_size) {
            ret = -EINVAL;
            break;
        }
        
        /* Set addresses */
        dma_addr_t input_addr = dev->mmap_dma + req.input_offset;
        dma_addr_t output_addr = dev->mmap_dma + req.output_offset;
        
        bitnet_write(dev, BITNET_REG_INPUT_ADDR_LO, lower_32_bits(input_addr));
        bitnet_write(dev, BITNET_REG_INPUT_ADDR_HI, upper_32_bits(input_addr));
        bitnet_write(dev, BITNET_REG_OUTPUT_ADDR_LO, lower_32_bits(output_addr));
        bitnet_write(dev, BITNET_REG_OUTPUT_ADDR_HI, upper_32_bits(output_addr));
        bitnet_write(dev, BITNET_REG_INPUT_SIZE, req.input_size);
        bitnet_write(dev, BITNET_REG_OUTPUT_SIZE, req.output_size);
        
        /* Start inference */
        reinit_completion(&dev->inference_done);
        ret = bitnet_hw_start_inference(dev);
        break;
    }
    
    case BITNET_IOC_LOAD_WEIGHTS: {
        struct bitnet_weight_req req;
        
        if (copy_from_user(&req, argp, sizeof(req))) {
            ret = -EFAULT;
            break;
        }
        
        /* Validate offset */
        if (req.weight_offset + req.weight_size > dev->mmap_size) {
            ret = -EINVAL;
            break;
        }
        
        /* Set weight address */
        dma_addr_t weight_addr = dev->mmap_dma + req.weight_offset;
        
        bitnet_write(dev, BITNET_REG_WEIGHT_ADDR_LO, lower_32_bits(weight_addr));
        bitnet_write(dev, BITNET_REG_WEIGHT_ADDR_HI, upper_32_bits(weight_addr));
        
        /* TODO: Trigger weight loading if needed */
        break;
    }
    
    case BITNET_IOC_GET_STATUS: {
        struct bitnet_status status;
        
        status.state = dev->state;
        status.current_layer = bitnet_read(dev, BITNET_REG_CURRENT_LAYER);
        status.tokens_processed = 0; /* TODO */
        status.error_code = dev->last_error;
        
        if (copy_to_user(argp, &status, sizeof(status)))
            ret = -EFAULT;
        break;
    }
    
    case BITNET_IOC_WAIT_COMPLETE: {
        mutex_unlock(&dev->lock);
        
        ret = wait_for_completion_interruptible_timeout(
            &dev->inference_done, 
            msecs_to_jiffies(INFERENCE_TIMEOUT_MS));
        
        if (ret == 0)
            return -ETIMEDOUT;
        if (ret < 0)
            return ret;
        
        return dev->state == BITNET_STATE_ERROR ? -EIO : 0;
    }
    
    case BITNET_IOC_ABORT:
        bitnet_hw_abort(dev);
        break;
    
    case BITNET_IOC_GET_PERF: {
        struct bitnet_perf perf;
        
        perf.total_cycles = dev->total_cycles;
        perf.dma_cycles = 0; /* TODO */
        perf.compute_cycles = bitnet_read(dev, BITNET_REG_CYCLE_COUNT);
        perf.tokens_per_second = 0; /* TODO: calculate */
        
        if (copy_to_user(argp, &perf, sizeof(perf)))
            ret = -EFAULT;
        break;
    }
    
    case BITNET_IOC_RESET:
        ret = bitnet_hw_reset(dev);
        break;
    
    default:
        ret = -ENOTTY;
    }
    
    mutex_unlock(&dev->lock);
    return ret;
}

static unsigned int bitnet_poll(struct file *file, poll_table *wait)
{
    struct bitnet_dev *dev = file->private_data;
    unsigned int mask = 0;
    
    poll_wait(file, &dev->wait_queue, wait);
    
    if (dev->state == BITNET_STATE_IDLE || 
        dev->state == BITNET_STATE_ERROR) {
        mask |= POLLIN | POLLRDNORM;
    }
    
    return mask;
}

static const struct file_operations bitnet_fops = {
    .owner          = THIS_MODULE,
    .open           = bitnet_open,
    .release        = bitnet_release,
    .mmap           = bitnet_mmap,
    .unlocked_ioctl = bitnet_ioctl,
    .poll           = bitnet_poll,
};

/* ═══════════════════════════════════════════════════════════════════════════
 * Platform driver
 * ═══════════════════════════════════════════════════════════════════════════ */

static int bitnet_probe(struct platform_device *pdev)
{
    struct bitnet_dev *dev;
    struct resource *res;
    int ret;
    
    dev_info(&pdev->dev, "VIBEE BitNet driver v%s\n", DRIVER_VERSION);
    
    /* Allocate device structure */
    dev = devm_kzalloc(&pdev->dev, sizeof(*dev), GFP_KERNEL);
    if (!dev)
        return -ENOMEM;
    
    dev->dev = &pdev->dev;
    platform_set_drvdata(pdev, dev);
    
    mutex_init(&dev->lock);
    init_completion(&dev->inference_done);
    init_waitqueue_head(&dev->wait_queue);
    
    /* Get register resource */
    res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
    dev->regs = devm_ioremap_resource(&pdev->dev, res);
    if (IS_ERR(dev->regs)) {
        dev_err(&pdev->dev, "Failed to map registers\n");
        return PTR_ERR(dev->regs);
    }
    dev->regs_phys = res->start;
    dev->regs_size = resource_size(res);
    
    dev_info(&pdev->dev, "Registers mapped at 0x%llx (size: 0x%llx)\n",
             (u64)dev->regs_phys, (u64)dev->regs_size);
    
    /* Get IRQ */
    dev->irq = platform_get_irq(pdev, 0);
    if (dev->irq < 0) {
        dev_warn(&pdev->dev, "No IRQ specified, polling mode\n");
    } else {
        ret = devm_request_irq(&pdev->dev, dev->irq, bitnet_irq_handler,
                               IRQF_SHARED, DRIVER_NAME, dev);
        if (ret) {
            dev_err(&pdev->dev, "Failed to request IRQ %d\n", dev->irq);
            return ret;
        }
        dev_info(&pdev->dev, "IRQ %d registered\n", dev->irq);
    }
    
    /* Initialize reserved memory */
    ret = of_reserved_mem_device_init(&pdev->dev);
    if (ret) {
        dev_warn(&pdev->dev, "No reserved memory, using CMA\n");
    }
    
    /* Allocate DMA buffer for mmap */
    dev->mmap_size = MMAP_BUFFER_SIZE;
    dev->mmap_buf = dma_alloc_coherent(&pdev->dev, dev->mmap_size,
                                       &dev->mmap_dma, GFP_KERNEL);
    if (!dev->mmap_buf) {
        dev_err(&pdev->dev, "Failed to allocate DMA buffer\n");
        return -ENOMEM;
    }
    
    dev_info(&pdev->dev, "DMA buffer: virt=%p, dma=0x%llx, size=%zu\n",
             dev->mmap_buf, (u64)dev->mmap_dma, dev->mmap_size);
    
    /* Request DMA channels */
    dev->dma_input = dma_request_chan(&pdev->dev, "input");
    if (IS_ERR(dev->dma_input)) {
        dev_warn(&pdev->dev, "No input DMA channel\n");
        dev->dma_input = NULL;
    }
    
    dev->dma_output = dma_request_chan(&pdev->dev, "output");
    if (IS_ERR(dev->dma_output)) {
        dev_warn(&pdev->dev, "No output DMA channel\n");
        dev->dma_output = NULL;
    }
    
    dev->dma_weights = dma_request_chan(&pdev->dev, "weights");
    if (IS_ERR(dev->dma_weights)) {
        dev_warn(&pdev->dev, "No weights DMA channel\n");
        dev->dma_weights = NULL;
    }
    
    /* Get minor number */
    dev->minor = ida_simple_get(&bitnet_ida, 0, MAX_DEVICES, GFP_KERNEL);
    if (dev->minor < 0) {
        ret = dev->minor;
        goto err_dma;
    }
    
    /* Create character device */
    cdev_init(&dev->cdev, &bitnet_fops);
    dev->cdev.owner = THIS_MODULE;
    
    ret = cdev_add(&dev->cdev, MKDEV(bitnet_major, dev->minor), 1);
    if (ret) {
        dev_err(&pdev->dev, "Failed to add cdev\n");
        goto err_ida;
    }
    
    /* Create device node */
    device_create(bitnet_class, &pdev->dev, 
                  MKDEV(bitnet_major, dev->minor),
                  dev, "bitnet%d", dev->minor);
    
    /* Reset hardware */
    ret = bitnet_hw_reset(dev);
    if (ret) {
        dev_err(&pdev->dev, "Hardware reset failed\n");
        goto err_cdev;
    }
    
    /* Read version */
    u32 version = bitnet_read(dev, BITNET_REG_VERSION);
    dev_info(&pdev->dev, "Hardware version: %d.%d.%d\n",
             (version >> 16) & 0xFF,
             (version >> 8) & 0xFF,
             version & 0xFF);
    
    dev_info(&pdev->dev, "Device /dev/bitnet%d created\n", dev->minor);
    
    return 0;

err_cdev:
    cdev_del(&dev->cdev);
err_ida:
    ida_simple_remove(&bitnet_ida, dev->minor);
err_dma:
    if (dev->dma_input)
        dma_release_channel(dev->dma_input);
    if (dev->dma_output)
        dma_release_channel(dev->dma_output);
    if (dev->dma_weights)
        dma_release_channel(dev->dma_weights);
    dma_free_coherent(&pdev->dev, dev->mmap_size, dev->mmap_buf, dev->mmap_dma);
    return ret;
}

static int bitnet_remove(struct platform_device *pdev)
{
    struct bitnet_dev *dev = platform_get_drvdata(pdev);
    
    device_destroy(bitnet_class, MKDEV(bitnet_major, dev->minor));
    cdev_del(&dev->cdev);
    ida_simple_remove(&bitnet_ida, dev->minor);
    
    if (dev->dma_input)
        dma_release_channel(dev->dma_input);
    if (dev->dma_output)
        dma_release_channel(dev->dma_output);
    if (dev->dma_weights)
        dma_release_channel(dev->dma_weights);
    
    dma_free_coherent(&pdev->dev, dev->mmap_size, dev->mmap_buf, dev->mmap_dma);
    
    dev_info(&pdev->dev, "Device removed\n");
    
    return 0;
}

static const struct of_device_id bitnet_of_match[] = {
    { .compatible = "vibee,bitnet-1.0" },
    { /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, bitnet_of_match);

static struct platform_driver bitnet_driver = {
    .probe  = bitnet_probe,
    .remove = bitnet_remove,
    .driver = {
        .name = DRIVER_NAME,
        .of_match_table = bitnet_of_match,
    },
};

/* ═══════════════════════════════════════════════════════════════════════════
 * Module init/exit
 * ═══════════════════════════════════════════════════════════════════════════ */

static int __init bitnet_init(void)
{
    int ret;
    
    pr_info("VIBEE BitNet driver initializing\n");
    
    /* Allocate device numbers */
    ret = alloc_chrdev_region(&bitnet_devt, 0, MAX_DEVICES, DRIVER_NAME);
    if (ret) {
        pr_err("Failed to allocate chrdev region\n");
        return ret;
    }
    bitnet_major = MAJOR(bitnet_devt);
    
    /* Create device class */
    bitnet_class = class_create(THIS_MODULE, DRIVER_NAME);
    if (IS_ERR(bitnet_class)) {
        ret = PTR_ERR(bitnet_class);
        goto err_chrdev;
    }
    
    /* Register platform driver */
    ret = platform_driver_register(&bitnet_driver);
    if (ret) {
        pr_err("Failed to register platform driver\n");
        goto err_class;
    }
    
    pr_info("VIBEE BitNet driver v%s loaded\n", DRIVER_VERSION);
    return 0;

err_class:
    class_destroy(bitnet_class);
err_chrdev:
    unregister_chrdev_region(bitnet_devt, MAX_DEVICES);
    return ret;
}

static void __exit bitnet_exit(void)
{
    platform_driver_unregister(&bitnet_driver);
    class_destroy(bitnet_class);
    unregister_chrdev_region(bitnet_devt, MAX_DEVICES);
    ida_destroy(&bitnet_ida);
    
    pr_info("VIBEE BitNet driver unloaded\n");
}

module_init(bitnet_init);
module_exit(bitnet_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("VIBEE Project");
MODULE_DESCRIPTION("VIBEE BitNet Accelerator Driver");
MODULE_VERSION(DRIVER_VERSION);

//
//  ResampleUtil2.m
//  PCMEncode
//
//  Created by Du on 2022/3/30.
//

#import "ResampleUtil2.h"
#import <libswresample/swresample.h>

// 输入缓冲区的指针
static uint8_t **inData = NULL;
// 输入缓冲区的大小
static int inLinesize = 0;
// 输入缓冲区的声道数
int inChannels = 0;
// 输入缓冲区能存放的样本数量
static int inNbSamples = 1024;
// 输出缓冲区的指针
static uint8_t **outData = NULL;
// 输出缓冲区的大小
static int outLinesize = 0;
// 输出缓冲区的声道数
int outChannels = 0;
// 输出缓冲区能存放的样本数量
static int outNbSamples = 1024;
// 从文件中读取的数据大小
size_t size = 0;
// 输入文件
static FILE *inFile = NULL;
// 输出文件
static FILE *outFile = NULL;
// 输入缓冲区中，一个样本的大小
static int inBytesOfPerSample = 0;
// 输出缓冲区中，一个样本的大小
static int outBytesOfPerSample = 0;
// 重采样上下文
static struct SwrContext *swrCtx = NULL;

@implementation ResampleUtil2
/// 初始化重采样相关的变量
- (void)swrContext:(NSString *)inFName outFile:(NSString *)outFName {
    // 输出参数
    int32_t result = 0;
    // 输入参数
    int64_t inChLayout = AV_CH_LAYOUT_STEREO;
    enum AVSampleFormat inSampleFmt = AV_SAMPLE_FMT_S16;
    int inSampleRate = 44100;
    // 输出参数
    int64_t outChLayout = AV_CH_LAYOUT_STEREO;
    enum AVSampleFormat outSampleFmt = AV_SAMPLE_FMT_S16;
    int outSampleRate = 48000;
    /*
     创建 SwrContext 并设置相关参数
     原 PCM 数据：
        声道：AV_CH_LAYOUT_STEREO
        采样格式：AV_SAMPLE_FMT_S16
        采样率：44100
     重采样后的 PCM 数据：
        声道：AV_CH_LAYOUT_STEREO
        采样格式：AV_SAMPLE_FMT_S16P
        采样率：44100
     */
    swrCtx = swr_alloc_set_opts(NULL,
                                // 输出参数
                                outChLayout,
                                outSampleFmt,
                                outSampleRate,
                                // 输入参数
                                inChLayout,
                                inSampleFmt,
                                inSampleRate,
                                0,
                                NULL);
    if (!swrCtx) {
        fprintf(stderr, "Error: failed to alloc SwrContext.\n");
        goto end;
    }
    
    // 初始化 SwrContext
    result = swr_init(swrCtx);
    if (result < 0) {
        fprintf(stderr, "Error: failed to initalize SwrContext.\n");
        goto end;
    }
    
    // 创建输入缓冲区
    inChannels = av_get_channel_layout_nb_channels(inChLayout);
    result = av_samples_alloc_array_and_samples(&inData, &inLinesize, inChannels, inNbSamples, inSampleFmt, 1);
    if (result < 0) {
        fprintf(stderr, "Error: failed to alloc in Buffer.\n");
        goto end;
    }
    
    // 创建输出缓冲区
    outChannels = av_get_channel_layout_nb_channels(outChLayout);
    /*
     因为重采样后，样本的数量可能发生变化，所以需要根据输入的参数进行计算
     inNbSamples     44100
     ------------ = -------
     outNbSamples    48000
     输出缓冲区的样本数量，应该等于: (48000 *inNbSamples) / 44100
     */
    outNbSamples = (int)av_rescale_rnd(outSampleRate, inNbSamples, inSampleRate, AV_ROUND_UP);
    result = av_samples_alloc_array_and_samples(&outData, &outLinesize, outChannels, outNbSamples, outSampleFmt, 1);
    if (result < 0) {
        fprintf(stderr, "Error: failed to alloc out Buffer.\n");
        goto end;
    }
    
    // 打开文件
    inFile = [self openFile:[inFName UTF8String] isRead:YES];
    outFile = [self openFile:[outFName UTF8String] isRead:NO];
    
    inBytesOfPerSample = av_get_bytes_per_sample(inSampleFmt) *inChannels;
    outBytesOfPerSample = av_get_bytes_per_sample(outSampleFmt) *outChannels;
    while ((size = fread(inData[0], 1, inLinesize, inFile)) > 0) {
        /*
         计算实际读取样本的数量
         size：每次从文件读取的大小
         除以每个样本的大小，就得到实际读取样本数量
         */
        inNbSamples = (int)(size / inBytesOfPerSample);
        /*
         重采样
         result: 转换后的样本数量
         */
        result = swr_convert(swrCtx,
                             outData,
                             outNbSamples,
                             (const uint8_t **)inData,
                             inNbSamples);
        if (result < 0) {
            fprintf(stderr, "Error: swr_convert failed.\n");
            goto end;
        }
        
        fwrite(outData[0], 1, result *outBytesOfPerSample, outFile);
    }
    
    // 冲刷重采样缓冲区
    while ((result = swr_convert(swrCtx, outData, outNbSamples, NULL, 0)) > 0) {
        fwrite(outData[0], 1, result *outBytesOfPerSample, outFile);
    }
    
    
    printf("重采样结束.\n");
end:
    [self closeFiles];
    [self destoryAudioEncoder];
}

/// 打开文件
/// @param fileName 文件名称
- (FILE *)openFile:(const char *)fileName isRead:(BOOL)isRead {
    if (strlen(fileName) == 0) {
        fprintf(stderr, "Error: fileName is empty.\n");
        return NULL;
    }
    
    FILE *file = fopen(fileName, isRead ? "rb":"wb");
    if (file == NULL) {
        fprintf(stderr, "Error: failed to open file.\n");
        return NULL;
    }
    
    return file;
}

/// 回收资源
- (void)destoryAudioEncoder {
    if (swrCtx) {
        swr_free(&swrCtx);
    }
    
    if (inData) {
        av_freep(&inData);
    }
    
    if (outData) {
        av_freep(&outData);
    }
}

/// 关闭文件，并清空指针
- (void)closeFiles {
    if (inFile) {
        fclose(inFile);
        inFile = NULL;
    }
    
    if (outFile) {
        fclose(outFile);
        outFile = NULL;
    }
}
@end

//
//  ResampleUtil.m
//  PCMEncode
//
//  Created by Du on 2022/3/29.
//

#import "ResampleUtil.h"
#import <libswresample/swresample.h>
// 重采样上下文
static struct SwrContext *swrCtx = NULL;
// 输入缓冲区能存放的样本数量
static int srcNbSamples = 1024;
static int32_t srcRate = 0;
static AVFrame *inputFrame = NULL;
static int32_t srcNbChannels = 0;
enum AVSampleFormat srcSampleFmt = AV_SAMPLE_FMT_NONE;
static int64_t srcChLayout = 0;
// 输入文件
static FILE *srcFile = NULL;


static int32_t dstNbSamples = 0;
static int32_t maxDstNbSamples = 0;
static int32_t dstNbChannels = 0;
static int32_t dstRate = 0;
enum AVSampleFormat dstSampleFmt = AV_SAMPLE_FMT_NONE;
static int64_t dstChLayout = 0;
// 输出缓冲区的指针
static uint8_t **dstData = NULL;
// 输入缓冲区的大小
static int dstLinesize = 0;
// 输出文件
static FILE *dstFile = NULL;

@implementation ResampleUtil

#pragma mark - Helper
/// 关闭文件，并清空指针
- (void)closeFiles {
    if (srcFile) {
        fclose(srcFile);
        srcFile = NULL;
    }
    
    if (dstFile) {
        fclose(dstFile);
        dstFile = NULL;
    }
}

/// 判断文件到达尾部
- (int)endOfFile:(FILE *)file {
    if (!file) {
        fprintf(stderr, "Error: file is empty.\n");
        return 1;
    }
    return feof(file);
}

/// 将编码后的数据写入到文件中
- (void)writePacketToFile:(const uint8_t *)buf size:(int32_t)size {
    fwrite(buf, 1, size, dstFile);
}

- (void)destroyAudioResampler {
    if (inputFrame) {
        av_frame_free(&inputFrame);
    }
    if (dstData) av_freep(&dstData[0]);
    av_freep(&dstData);
    swr_free(&swrCtx);
}

/// 打开文件
/// @param inputFileName 输入文件名称-PCM 文件路径
/// @param outputFileName 输出文件名称-AAC、MP3 文件路径
- (int32_t)openInputFile:(const char *)inputFileName outputFile:(const char *)outputFileName {
    if (strlen(inputFileName) == 0 || strlen(outputFileName) == 0) {
        fprintf(stderr, "Error: input or output is empty.\n");
        return -1;
    }
    
    [self closeFiles];
    
    srcFile = fopen(inputFileName, "rb");
    if (srcFile == NULL) {
        fprintf(stderr, "Error: failed to open input file.\n");
        return -1;
    }
    
    dstFile = fopen(outputFileName, "wb");
    if (dstFile == NULL) {
        fprintf(stderr, "Error: failed to open output file.\n");
        return -1;
    }
    
    return 0;
}

#pragma mark - swrconvert
/// PCM 重采样
/// @param inFName 原 PCM 文件路径
/// @param outFName 重采样后的文件路径
- (void)swrContext:(NSString *)inFName outFile:(NSString *)outFName {
    int32_t result = 0;
    // 原 PCM 参数
    const char *inputFileName = [inFName UTF8String];
    srcRate = 44100;
    srcSampleFmt = AV_SAMPLE_FMT_FLTP;
    srcChLayout = AV_CH_LAYOUT_STEREO;
    
    // 重采样后 PCM 参数
    const char *outPutFileName = [outFName UTF8String];
    dstRate = 44100;
    dstSampleFmt = AV_SAMPLE_FMT_S16;
    dstChLayout = AV_CH_LAYOUT_STEREO;
   
    // 打开输入输出文件
    result = [self openInputFile:inputFileName outputFile:outPutFileName];
    if (result < 0) {
        goto end;
    }
    
    // 初始化重采样相关参数
    result = [self initAudioResampler];
    if (result < 0) {
        fprintf(stderr, "Error: init audio resampler failed");
        goto end;
    }
    
    // 进行重采样
    result = [self audioResampling];
    if (result < 0) {
        fprintf(stderr, "Error: audio resampleing failed");
        goto end;
    }
    
end:
    // 关闭文件
    [self closeFiles];
    // 回收资源
    [self destroyAudioResampler];
}

#pragma mark - Private
- (int32_t)initAudioResampler {
    int32_t result = 0;
    swrCtx = swr_alloc_set_opts(NULL,
                                // 输出参数
                                dstChLayout,
                                dstSampleFmt,
                                dstRate,
                                // 输入参数
                                srcChLayout,
                                srcSampleFmt,
                                srcRate,
                                0,
                                NULL);
    if (!swrCtx) {
        fprintf(stderr, "Error: failed to allocate SwrContext.\n");
        return -1;
    }
    
    // 初始化 SwrContext
    result = swr_init(swrCtx);
    if (result < 0) {
        fprintf(stderr, "Error: failed to initialize SwrContext.\n");
        return -1;
    }

    inputFrame = av_frame_alloc();
    if (!inputFrame) {
        fprintf(stderr, "Error: could not alloc input frame.\n");
        return -1;
    }
    
    result = [self initFrame:srcRate
                   sampleFmt:srcSampleFmt
               channelLayout:srcChLayout];
    if (result < 0) {
        fprintf(stderr, "Error: failed to initialize input frame.\n");
        return -1;
    }
    /*
     因为重采样后，样本的数量可能发生变化，所以需要根据相关参数进行计算
     srcNbSamples        srcRate
     --------------   =  --------
     outNbSamples        dstRate
     输出缓冲区的样本数量，应该等于: (dstRate *srcNbSamples) / srcRate
     */
    maxDstNbSamples = dstNbSamples = (int)av_rescale_rnd(srcNbSamples, dstRate, srcRate, AV_ROUND_UP);
    dstNbChannels = av_get_channel_layout_nb_channels(dstChLayout);
    fprintf(stderr, "maxDstNbSamples: %d.\n", maxDstNbSamples);
    fprintf(stderr, "dstNbChannels: %d.\n", dstNbChannels);
    return result;
}

- (int32_t)audioResampling {
    // 创建输出缓冲区
    int32_t result = av_samples_alloc_array_and_samples(&dstData,
                                                        &dstLinesize,
                                                        dstNbChannels,
                                                        dstNbSamples,
                                                        dstSampleFmt,
                                                        1);
    if (result < 0) {
        fprintf(stderr, "Error: av_samples_alloc_array_and_samples failed.\n");
        return -1;
    }

    fprintf(stderr, "dstLinesize: %d.\n", dstLinesize);
    srcNbChannels = av_get_channel_layout_nb_channels(srcChLayout);
    // 从输入文件读取 PCM 数据到输入缓冲区
    while (![self endOfFile:srcFile]) {
        result = [self readPCMToFrame];
        if (result < 0) {
            fprintf(stderr, "Error: read_pcm_to_frame failed.\n");
            return -1;
        }
        
        result = [self resamplingFrame];
        if (result < 0) {
            fprintf(stderr, "Error: resampling_frame failed.\n");
            return -1;
        }
    }
    
    // 冲刷重采样缓冲区
    while ((result = swr_convert(swrCtx, dstData, dstNbSamples, NULL, 0)) > 0) {
        int32_t dstBufsize = 0;
        dstBufsize = av_samples_get_buffer_size(&dstLinesize,
                                                 dstNbChannels,
                                                 result,
                                                 dstSampleFmt,
                                                 1);
        [self writePacketToFile:dstData[0] size:dstBufsize];
    }
    
    return result;
}

- (int32_t)resamplingFrame {
    int32_t result = 0;
    int32_t dstBufsize = 0;
    // 计算积压的延迟数据
    int64_t delay = swr_get_delay(swrCtx, srcRate);
    /*
     计算实际读取样本的数量
     size：每次从文件读取的大小
     除以每个样本的大小，就得到实际读取样本数量
     */
    dstNbSamples = (int32_t)av_rescale_rnd(delay + srcNbSamples, dstRate, srcRate, AV_ROUND_UP);
    if (dstNbSamples > maxDstNbSamples) {
        av_freep(&dstData[0]);
        result = av_samples_alloc(dstData,
                                  &dstLinesize,
                                  dstNbChannels,
                                  dstNbSamples,
                                  dstSampleFmt,
                                  1);
        if (result < 0) {
            fprintf(stderr, "Error:failed to reallocat dstData.\n");
            return -1;
        }
        fprintf(stderr, "nbSamples exceeds maxDstNbSamples, buffer reallocated\n");
        maxDstNbSamples = dstNbSamples;
    }
    /*
     重采样
     result: 转换后的样本数量
     */
    result = swr_convert(swrCtx,
                         dstData,
                         dstNbSamples,
                         (const uint8_t **)inputFrame->data,
                         srcNbSamples);
    if (result < 0) {
        fprintf(stderr, "Error:swr_convert failed.\n");
        return -1;
    }
    // 返回指定格式音频的缓存大小
    dstBufsize = av_samples_get_buffer_size(&dstLinesize,
                                             dstNbChannels,
                                             result,
                                             dstSampleFmt,
                                             1);
    if (dstBufsize < 0) {
        fprintf(stderr, "Error:Could not get sample buffer size.\n");
        return -1;
    }
    
    printf("dstBufSize: %d.\n", dstBufsize);
    [self writePacketToFile:dstData[0] size:dstBufsize];
    return result;
}

- (int32_t)readPCMToFrame {
    // 单个声道一个样本的大小（假如是两声道就是一个 L，或者是一个 R的大小）
    int singleSize = av_get_bytes_per_sample(srcSampleFmt);
    // 所有声道单个样本的总大小（假如是两声道就是一个LR）
    int totalSize = srcNbChannels *singleSize;
    if (singleSize < 0) {
        /* This should not occur, checking just for paranoia */
        fprintf(stderr, "Failed to calculate sample size.\n");
        return -1;
    }
    
    if (av_sample_fmt_is_planar(srcSampleFmt)) {// PCM 是 planar
        /*
         假如 PCM 是这样：LLLLLRRRRR
         那单个声道的样本数就是：frame->nb_samples，这里等于5;
         那声道数这里等于2
         */
        for (int sampleIdx = 0; sampleIdx < srcNbSamples; sampleIdx++) {// for:单个声道的样本数
            for (int channelIdx = 0; channelIdx < srcNbChannels; channelIdx++) {//for: 声道数
                // 写入frame的顺序是：先左声道写入一个样本L；再右声道写入一个样本R；然后移动指针，指向下个样本；然后重复上面的操作，直到文件尾部
                fread(inputFrame->data[channelIdx] + sampleIdx *singleSize, 1, singleSize, srcFile);
            }
        }
    } else {// PCM 是 packed
        fread(inputFrame->data[0], 1, totalSize *srcNbSamples, srcFile);
    }
    return 0;
}

// 初始化inputFrame
- (int32_t)initFrame:(int)sampleRate sampleFmt:(int)sampleFmt channelLayout:(uint64_t)channelLayout {
    int32_t result = 0;
    
    inputFrame->sample_rate = sampleRate;
    inputFrame->nb_samples = srcNbSamples;
    inputFrame->format = sampleFmt;
    inputFrame->channel_layout = channelLayout;
    inputFrame->channels = av_get_channel_layout_nb_channels(channelLayout);
    
    // 设置好 inputFrame 参数后，可以创建重采样前的缓冲区
    result = av_frame_get_buffer(inputFrame, 0);
    if (result < 0) {
        fprintf(stderr, "Error: AVFrame could not get buffer.\n");
        return -1;
    }
    
    return result;
}
@end

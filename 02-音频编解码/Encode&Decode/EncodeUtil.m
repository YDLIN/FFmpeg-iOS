//
//  EncodeUtil.m
//  PCMEncode
//
//  Created by Du on 2022/3/27.
//

#import "EncodeUtil.h"
#import "ResampleUtil.h"

// 输入文件
static FILE *inputFile = NULL;
// 输出文件
static FILE *outputFile = NULL;
// 编码器
static AVCodec *codec = NULL;
// 编码器上下文
static AVCodecContext *codecCtx = NULL;
// AVFrame
static AVFrame *frame = NULL;
// AVPacket
static AVPacket *pkt = NULL;

@interface EncodeUtil()
@property (strong, nonatomic) ResampleUtil *resampleUtil;
@end


@implementation EncodeUtil
#pragma mark - API
- (void)convertPCMToAAC {
    self.resampleUtil = [[ResampleUtil alloc] init];
    [self convertWithType:"AAC"];
}

#pragma mark - Main
- (void)convertWithType:(const char *)type {
    // 输入文件路径
    NSString *pcmPath = [[NSBundle mainBundle] pathForResource:@"44100_2_f32le.pcm" ofType:nil];
    // 重采样后的路径
    NSString *rePCMPath = [Tool creatPCMDataFileName];
    // 编码后的文件路径
    NSString *aacPath = [Tool creatAACDataFileName];
    // 重采样
    [self.resampleUtil swrContext:pcmPath outFile:rePCMPath];
    
    int32_t result = [self openInputFile:[rePCMPath UTF8String]
                              outputFile:[aacPath UTF8String]];
    if (result < 0) {
        goto end;
    }
    
    result = [self initAudioEncoder:type];
    if (result < 0) {
        goto end;
    }
    
    result= [self audioEncoding];
    if (result < 0) {
        goto end;
    }
    
    printf("Encode Completed.\n");
    
end:
    [self destoryAudioEncoder];
    [self closeFiles];
}

#pragma mark - Private
/// 打开文件
/// @param inputFileName 输入文件名称-PCM 文件路径
/// @param outputFileName 输出文件名称-AAC 文件路径
- (int32_t)openInputFile:(const char *)inputFileName outputFile:(const char *)outputFileName {
    if (strlen(inputFileName) == 0 || strlen(outputFileName) == 0) {
        fprintf(stderr, "Error: input or output is empty.\n");
        return -1;
    }
    
    [self closeFiles];
    
    inputFile = fopen(inputFileName, "rb");
    if (inputFile == NULL) {
        fprintf(stderr, "Error: failed to open input file.\n");
        return -1;
    }
    
    outputFile = fopen(outputFileName, "wb");
    if (outputFile == NULL) {
        fprintf(stderr, "Error: failed to open output file.\n");
        return -1;
    }
    
    return 0;
}

/// 初始化音频编码器等
- (int32_t)initAudioEncoder:(const char *)codecName {
    if (strcasecmp(codecName, "AAC") == 0) {
        // 可以使用 libfdk_aac 进行编码（AV_CODEC_ID_AAC表示 FFmpeg 官方自带的 AAC 编解码器）
        codec = avcodec_find_encoder_by_name("libfdk_aac");
        printf("codec id: AAC.\n");
    } else {
        fprintf(stderr, "Error: invalid audio format.\n");
        return -1;
    }
    if (!codec) {
        fprintf(stderr, "Error: could not find codec.\n");
        return -1;
    }
    
    // 初始化解码器上下文
    codecCtx = avcodec_alloc_context3(codec);
    if (!codecCtx) {
        fprintf(stderr, "Error: could not alloc codec.\n");
        return -1;
    }

    codecCtx->sample_rate = 44100;
    codecCtx->channel_layout = AV_CH_LAYOUT_STEREO;
    codecCtx->channels = av_get_channel_layout_nb_channels(codecCtx->channel_layout);
    codecCtx->profile = FF_PROFILE_AAC_LOW;// 默认值
    codecCtx->bit_rate = 128000;
    codecCtx->sample_fmt = AV_SAMPLE_FMT_S16;
    // 检查编码器是否支持该采样格式
    if ([self checkSampleFormat:codec sampleFormat:codecCtx->sample_fmt] <= 0) {
        fprintf(stderr, "Error: encoder does not support sample format: %s",
                av_get_sample_fmt_name(codecCtx->sample_fmt));
        return -1;
    }
    
    
    // 打开编码器
    int32_t result = avcodec_open2(codecCtx, codec, NULL);
    if (result < 0) {
        fprintf(stderr, "Error: could not open codec.\n");
        return -1;
    }
    
    // 初始化 AVFrame
    frame = av_frame_alloc();
    if (!frame) {
        fprintf(stderr, "Error: could not alloc frame.\n");
        return -1;
    }
    
    frame->nb_samples = codecCtx->frame_size;
    frame->format = codecCtx->sample_fmt;
    frame->channel_layout = codecCtx->channel_layout;
    frame->sample_rate = codecCtx->sample_rate;
    // 设置好 frame 参数后，可以创建 PCM 缓冲区
    result = av_frame_get_buffer(frame, 0);
    if (result < 0) {
        fprintf(stderr, "Error: frame could not get buffer.\n");
        return -1;
    }
    
    // 初始化 AVPacket
    pkt = av_packet_alloc();
    if (!pkt) {
        fprintf(stderr, "Error: could not alloc packet.\n");
        return -1;
    }
    
    return 0;
}

/// 读取 PCM 数据到 AVFrame
/// @param frame AVFrame（最后存在 AVFrame 中的数据是多个声道交替存储的，而非 planar）
/// @param codecCtx 编码器上下文
/// @param size 读取文件的大小
- (int32_t)readPCMToFrame:(AVFrame *)frame codecContext:(AVCodecContext *)codecCtx readSize:(size_t *)size {
    // 单个声道一个样本的大小（假如是两声道就是一个 L，或者是一个 R）
    int singleSize = av_get_bytes_per_sample(codecCtx->sample_fmt);
    // 所有声道单个样本的总大小（假如是两声道就是一个LR）
    int totalSize = codecCtx->channels *singleSize;
    if (singleSize < 0) {
        fprintf(stderr, "Error: failed to calculate data size");
        return -1;
    }
    
    if (av_sample_fmt_is_planar(codecCtx->sample_fmt)) {// PCM 是 planar
        /*
         假如 PCM 是这样：LLLLLRRRRR
         那单个声道的样本数就是：frame->nb_samples，这里等于5;
         那声道数就是2
         */
        for (int sampleIdx = 0; sampleIdx < frame->nb_samples; sampleIdx++) {// for:单个声道的样本数
            for (int channelIdx = 0; channelIdx < codecCtx->channels; channelIdx++) {//for: 声道数
                // 写入frame的顺序是：先左声道写入一个样本L；再右声道写入一个样本R；然后移动指针，指向下个样本；然后重复上面的操作，直到文件尾部
                *size = fread(frame->data[channelIdx] + sampleIdx *singleSize, 1, singleSize, inputFile);
            }
        }
    } else {// PCM 是 packed
        *size = fread(frame->data[0], 1, totalSize *frame->nb_samples, inputFile);
    }
    
    return 0;
}

// 音频编码
- (int32_t)audioEncoding {
    size_t size = 0;
    int32_t result = 0;
    while (![self endOfFile]) {
        result = [self readPCMToFrame:frame
                         codecContext:codecCtx
                             readSize:&size];
        
        
        if (result < 0) {
            fprintf(stderr, "Error: readPCMToFrame:codecContext: failed.\n");
            return -1;
        }
        
        // 编码
        result = [self encodeFrameWithFlushing:NO];
        if (result < 0) {
            fprintf(stderr, "Error: encodeFrame: failed.\n");
            return result;
        }
    }
    
    // 冲刷缓冲区
    result = [self encodeFrameWithFlushing:YES];
    if (result < 0) {
        fprintf(stderr, "Error: flushing failed.\n");
        return result;
    }
    return 0;
}

// 编码
- (int32_t)encodeFrameWithFlushing:(BOOL)flushing {
    int32_t result = 0;
    /*
     从 frame 中获取到重采样后的 PCM 数据，然后将数据发送到 codec 中.
     frame为 NULL 的时候，表示冲刷缓冲区
     */
    result = avcodec_send_frame(codecCtx, flushing ? NULL : frame);
    if (result < 0) {
        fprintf(stderr, "Error: avcodec_send_frame failed.\n");
        return -1;
    }
    
    while (result >= 0) {
        // 从编码器中获取编码后的数据，存放到 AVPacket 中
        result = avcodec_receive_packet(codecCtx, pkt);
        // AVERROR(EAGAIN): 编码器还没有完成对新的 1 帧的编码，应该继续通过函数 avcodec_send_frame 传入后续的图像
        // AVERROR_EOF: 编码器已经完全输出内部的数据，编码完成
        if (result == AVERROR(EAGAIN) || result == AVERROR_EOF) {
            return 1;
        } else if (result < 0) {
            fprintf(stderr, "Error: avcodec_receive_packet failed.\n");
            return result;
        }
        // 写入文件
        [self writePacketToFile:pkt];
        // 释放 pkt 所指向的缓冲区的引用
        av_packet_unref(pkt);
    }
    
    return 0;
}

#pragma mark - Helper
/// 检查编码器是否支持某种样本格式
/// @param codec 编码器
/// @param sampleFmt 样本格式
- (int)checkSampleFormat:(const AVCodec *)codec sampleFormat:(enum AVSampleFormat)sampleFmt {
    // 编码器支持的样本格式列表
    const enum AVSampleFormat *fmtPtr = codec->sample_fmts;
    while (*fmtPtr != AV_SAMPLE_FMT_NONE) {
        printf("Current codec's sample_fmts: %s.\n", av_get_sample_fmt_name(*fmtPtr));
        if (*fmtPtr == sampleFmt) {
            return 1;
        }
        fmtPtr++;
    }
    return 0;
}

/// 判断文件到达尾部
- (int)endOfFile {
    return feof(inputFile);
}

/// 将编码后的数据写入到文件中
/// @param pkt 码流包
- (void)writePacketToFile:(AVPacket *)pkt {
    fwrite(pkt->data, 1, pkt->size, outputFile);
}

#pragma mark - End/Error
/// 关闭文件，并清空指针
- (void)closeFiles {
    if (inputFile) {
        fclose(inputFile);
        inputFile = NULL;
    }
    
    if (outputFile) {
        fclose(outputFile);
        outputFile = NULL;
    }
}

/// 回收资源
- (void)destoryAudioEncoder {
    if (frame) {
        av_frame_free(&frame);
    }
    if (pkt) {
        av_packet_free(&pkt);
    }
    if (codecCtx) {
        avcodec_free_context(&codecCtx);
    }
}
@end

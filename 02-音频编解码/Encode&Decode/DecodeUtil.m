//
//  DecodeUtil.m
//  Encode&Decode
//
//  Created by Du on 2022/3/31.
//

#import "DecodeUtil.h"

// 输入缓冲区的大小
#define AUDIO_INBUF_SIZE 20480
// 需要再次读取输入文件数据的阈值
#define AUDIO_REFILL_THRESH 4096

static AVCodec *codec = NULL;
static AVCodecContext *codec_ctx = NULL;
static AVCodecParserContext *parser = NULL;
// AVPacket: 存放解码前的数据
static AVPacket *pkt = NULL;
// AVFrame: 存放解码前的数据
static AVFrame *frame = NULL;
static FILE *srcFile = NULL;
const char *srcFileName = NULL;
static FILE *dstFile = NULL;
const char *dstFileName = NULL;

@implementation DecodeUtil
#pragma mark - API
- (void)decodeAudio {
    int result = 0;
//    srcFileName = [[Tool creatAACDataFileName] UTF8String];
    srcFileName = [[[NSBundle mainBundle] pathForResource:@"src.aac" ofType:nil] UTF8String];
    dstFileName = [[Tool creatPCMDataFileName] UTF8String];
    // 打开文件
    result = [self opensrcfile:srcFileName dstfile:dstFileName];
    if (result < 0) {
        goto end;
    }
    
    // 初始化解码器
    result = [self initAudioDecoder:"AAC"];
    if (result < 0) {
        goto end;
    }
    
    // 进行解码
    result = [self audioDecoding];
    if (result < 0) {
        goto end;
    }
    
end:
    // 释放资源
    [self destroyAudioDecoder];
    // 关闭文件
    [self closeFiles];
}


// 初始化音频解码器等
- (int32_t)initAudioDecoder:(char *)audioCodec {
    if (!strcasecmp(audioCodec, "AAC")) {
//        codec = avcodec_find_decoder(AV_CODEC_ID_AAC);
        codec = avcodec_find_decoder_by_name("libfdk_aac");
        printf("Codec id: AAC.\n");
        printf("Codec name: %s.\n", codec->name);
    } else {
        fprintf(stderr, "Error: invalid audio format.\n");
        return -1;
    }
    
    if (!codec) {
        fprintf(stderr, "Error: could not find codec.\n");
        return -1;
    }
    
    parser = av_parser_init(codec->id);
    if (!parser) {
        fprintf(stderr, "Error: could not init parser.\n");
        return -1;
    }
    
    codec_ctx = avcodec_alloc_context3(codec);
    if (!codec_ctx) {
        fprintf(stderr, "Error: could not alloc codec.\n");
        return -1;
    }
    
    int32_t result = avcodec_open2(codec_ctx, codec, NULL);
    if (result < 0) {
        fprintf(stderr, "Error: could not open codec.\n");
        return -1;
    }
    frame = av_frame_alloc();
    if (!frame) {
        fprintf(stderr, "Error: could not alloc frame.\n");
        return -1;
    }
    
    pkt = av_packet_alloc();
    if (!pkt) {
        fprintf(stderr, "Error: could not alloc packet.\n");
        return -1;
    }
    return 0;
}

- (int32_t)audioDecoding {
    // AV_INPUT_BUFFER_PADDING_SIZE: 用来防止读取过多而产生越界行为
    uint8_t inbuf[AUDIO_INBUF_SIZE + AV_INPUT_BUFFER_PADDING_SIZE] = { 0 };
    int32_t result = 0;
    // 指向存放 inbuf 的指针
    uint8_t *data = NULL;
    // 每次读取数据的大小
    int32_t dataSize = 0;
    while (![self endOfFile:srcFile]) {
        // 从输入文件读取数据到 inbuf 中
        result = [self readDataToBuf:inbuf size:AUDIO_INBUF_SIZE outSize:&dataSize];
        if (result < 0) {
            fprintf(stderr, "Error: readDataToBuf:size:outSize: failed.\n");
            return -1;
        }
        
        // 每次从文件中读取数据，都需要将 data 指回 inbuf 首元素
        data = inbuf;
        while (dataSize > 0) {
            // 解析器处理数据，并放到 pkt 中; result: 已经解码的数据
            result = av_parser_parse2(parser,
                                      codec_ctx,
                                      &pkt->data,
                                      &pkt->size,
                                      data,
                                      dataSize,
                                      AV_NOPTS_VALUE,
                                      AV_NOPTS_VALUE,
                                      0);
            if (result < 0) {
                fprintf(stderr, "Error: av_parser_parse2 failed.\n");
                return -1;
            }

            // 跳过已经解析好的数据
            data += result;
            // 减去已经解析过的数据（因为从文件中读取的数据，解析器不一定一次性能处理完）
            dataSize -= result;
            
            // 解码
            if (pkt->size) {
//                printf("Parsed packet size: %d.\n", pkt->size);
                [self decodePacket:NO];
            }
        }
    }
    
    // 冲刷缓冲区
    [self decodePacket:YES];
    [self printFileSize];
    [self getAudioFormat:codec_ctx];
    return 0;
}

- (int32_t)decodePacket:(BOOL)flushing {
    int32_t result = 0;
    result = avcodec_send_packet(codec_ctx, flushing ? NULL : pkt);
    if (result < 0) {
        fprintf(stderr, "Error: faile to send packet, result: %d\n", result);
        return -1;
    }
    while (result >= 0) {
        result = avcodec_receive_frame(codec_ctx, frame);
        if (result == AVERROR(EAGAIN) || result == AVERROR_EOF) {
            return 1;
        } else if (result < 0) {
            fprintf(stderr, "Error: faile to receive frame, result: %d\n", result);
            return -1;
        }
        
        if (flushing) {
            printf("Flushing:");
        }
        
        result = [self writeSamplesToPcm:frame codecCtx:codec_ctx];
        
        if (result < 0) {
            fprintf(stderr, "Error: write samples to pcm failed.\n");
            return -1;
        }
//        printf("frame->nb_samples: %d\n", frame->nb_samples);
//        printf("frame->channels: %d\n", frame->channels);
  }
  return result;
}

- (int32_t)getAudioFormat:(AVCodecContext *)codecCtx {
    int ret = 0;
    const char *fmt;
    enum AVSampleFormat sfmt = codecCtx->sample_fmt;
    if (av_sample_fmt_is_planar(sfmt)) {
        const char *packed = av_get_sample_fmt_name(sfmt);
        printf("Warning: the sample format the decoder produced is planar ");
        printf("%s", packed);
        printf(", This example will output the first channel only.\n");
        sfmt = av_get_packed_sample_fmt(sfmt);
    }

//    int n_channels = codec_ctx->channels;
    
    if ((ret = [self getFormatFromSampleFmt:&fmt sampleFmt:sfmt]) < 0) {
        return -1;
    }

//  std::cout << "Play command: ffpay -f " << std::string(fmt) << " -ac "
//            << n_channels << " -ar " << codec_ctx->sample_rate << " output.pcm"
//            << std::endl;
  return 0;
}

- (int)getFormatFromSampleFmt:(const char **)fmt sampleFmt:(enum AVSampleFormat)sampleFmt {
    int i;
    struct sample_fmt_entry {
        enum AVSampleFormat sample_fmt;
        const char *fmt_be, *fmt_le;
    } sample_fmt_entries[] = {
        {AV_SAMPLE_FMT_U8, "u8", "u8"},
        {AV_SAMPLE_FMT_S16, "s16be", "s16le"},
        {AV_SAMPLE_FMT_S32, "s32be", "s32le"},
        {AV_SAMPLE_FMT_FLT, "f32be", "f32le"},
        {AV_SAMPLE_FMT_DBL, "f64be", "f64le"},
    };
    *fmt = NULL;

    for (i = 0; i < FF_ARRAY_ELEMS(sample_fmt_entries); i++) {
        struct sample_fmt_entry *entry = &sample_fmt_entries[i];
        if (sampleFmt == entry->sample_fmt) {
            *fmt = AV_NE(entry->fmt_be, entry->fmt_le);
            return 0;
        }
    }
    
    printf("sample format %s is not supported as output format.\n", av_get_sample_fmt_name(sampleFmt));
    return -1;
}

/// 从 AVFrame 中获取解码后的数据，写入文件
- (int32_t)writeSamplesToPcm:(AVFrame *)frame codecCtx:(AVCodecContext*)codecCtx {
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
                fwrite(frame->data[channelIdx] + sampleIdx *singleSize, 1, singleSize, dstFile);
            }
        }
    } else {// PCM 是 packed
        fwrite(frame->data[0], 1, totalSize *frame->nb_samples, dstFile);
    }
    return 0;
}

/// 判断文件到达尾部
- (int)endOfFile:(FILE *)file {
    if (!file) {
        fprintf(stderr, "Error: file is empty.\n");
        return 1;
    }
    return feof(file);
}

- (int32_t)readDataToBuf:(uint8_t*)buf size:(int32_t)size outSize:(int32_t *)outSize {
    size_t readSize = fread(buf, 1, size, srcFile);
    if (readSize == 0) {
        fprintf(stderr, "Error: readDataToBuf:size:outSize: failed.\n");
        return -1;
    }
    *outSize = (int32_t)readSize;
    return 0;
}

/// 打开文件
/// @param srcfileName 输入文件名称-PCM 文件路径
/// @param outfileName 输出文件名称-AAC 文件路径
- (int32_t)opensrcfile:(const char *)srcfileName dstfile:(const char *)outfileName {
    if (strlen(srcfileName) == 0 || strlen(outfileName) == 0) {
        fprintf(stderr, "Error: input or output is empty.\n");
        return -1;
    }
    [self closeFiles];
    srcFile = fopen(srcfileName, "rb");
    if (srcFile == NULL) {
        fprintf(stderr, "Error: failed to open input file.\n");
        return -1;
    }
    
    dstFile = fopen(outfileName, "wb");
    if (dstFile == NULL) {
        fprintf(stderr, "Error: failed to open output file.\n");
        return -1;
    }
    
    return 0;
}

#pragma mark - End/Error
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

// 释放资源
- (void)destroyAudioDecoder {
    av_parser_close(parser);
    avcodec_free_context(&codec_ctx);
    av_frame_free(&frame);
    av_packet_free(&pkt);
}

- (void)printFileSize {
    NSString *path = [Tool fetchPCMFilePath];
    NSFileManager* manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:path]) {
        NSLog(@"Decoded PCM file size: %llu bytes", [[manager attributesOfItemAtPath:path error:nil] fileSize]);
    }
}
@end

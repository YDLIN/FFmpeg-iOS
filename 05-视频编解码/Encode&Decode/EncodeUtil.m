//
//  EncodeUtil.m
//  YUVToH264
//
//  Created by Du on 2022/3/16.
//

#import "EncodeUtil.h"
#include <libavutil/time.h>
#include <libavutil/opt.h>

static AVCodec *codec = NULL;
static AVCodecContext *codecCtx = NULL;
static AVFrame *frame = NULL;
static AVPacket *pkt = NULL;
static FILE *inputFile = NULL;
static FILE *outputFile = NULL;
static int perImgSize = 0;
static enum AVPixelFormat pixFmt = AV_PIX_FMT_YUV420P;

@implementation EncodeUtil
/****************************Begin****************************/
- (void)startEncode2 {
    // 先清空文件
    NSString *h264Files = [[Tool getLibraryCachesPath] stringByAppendingPathComponent:@"H264Files"];
    [Tool deleteAllFileAtPath:h264Files];
    
    int32_t result = 0;
    // 输入文件路径
    NSString *yuvPath = [[NSBundle mainBundle] pathForResource:@"encode.yuv" ofType:nil];
    NSAssert(yuvPath.length > 0, @"请自行添加 YUV 文件，或者先解码 h264 文件");
    // 编码后的文件路径
    
    NSString *h264Path = [Tool creatH264FilePath];
    
    result = [self openInputFile:[yuvPath UTF8String]
                      outputFile:[h264Path UTF8String]];
    if (result < 0) {
        goto end;
    }
    
    result = [self initVideoEncoder:"libx264"];
    if (result < 0) {
        goto end;
    }
    
    result = [self encoding];
    if (result < 0) {
        goto end;
    }
    
end:
    [self destoryVideoEncoder];
    [self closeFiles];
}

- (int32_t)initVideoEncoder:(const char *)codecName {
    if (strlen(codecName) == 0) {
        fprintf(stderr, "Error: empty codec name.\n");
        return -1;
    }
    
    codec = avcodec_find_encoder_by_name(codecName);
    if (!codec) {
        fprintf(stderr, "Error: could not find codec with codec name: %s.\n", codecName);
        return -1;
    }
    
    // 检查像素格式
    if (![self checkPixFmt:codec fmt:pixFmt]) {
        fprintf(stderr, "Error: could not support pixel format:%s.\n", av_get_pix_fmt_name(pixFmt));
        return -1;
    }
    
    codecCtx = avcodec_alloc_context3(codec);
    if (!codecCtx) {
        fprintf(stderr, "Error: could not allocate video codec context.\n");
        return -1;
    }

    // 设置编码参数
    codecCtx->profile = FF_PROFILE_H264_HIGH;
    codecCtx->bit_rate = 2000000;
    codecCtx->width = 1920;
    codecCtx->height = 1080;
    codecCtx->gop_size = 10;
    codecCtx->time_base = (AVRational){1, 25};
    codecCtx->framerate = (AVRational){25, 1};
    // I 帧与 P帧之间，最多插入3个 B 帧
    codecCtx->max_b_frames = 3;
    codecCtx->pix_fmt = pixFmt;
    
    // 1920x1080x1.5 = 3110400
    perImgSize = av_image_get_buffer_size(codecCtx->pix_fmt, codecCtx->width, codecCtx->height, 1);

    if (codec->id == AV_CODEC_ID_H264) {
        av_opt_set(codecCtx->priv_data, "preset", "slow", 0);
        // 为了降低延迟
        av_opt_set(codecCtx->priv_data, "tune", "zerolatency", 0);
    }

    // 使用指定的 codec 初始化编码器上下文结构
    int32_t result = avcodec_open2(codecCtx, codec, NULL);
    if (result < 0) {
        fprintf(stderr, "Error: could not open codec:%s.\n", av_err2str(result));
        return -1;
    }

    pkt = av_packet_alloc();
    pkt->data = NULL;
    pkt->size = 0;
    if (!pkt) {
        fprintf(stderr, "Error: could not allocate AVPacket.\n");
        return -1;
    }

    frame = av_frame_alloc();
    if (!frame) {
        fprintf(stderr, "Error: could not allocate AVFrame.\n");
        return -1;
    }
    frame->width = codecCtx->width;
    frame->height = codecCtx->height;
    frame->format = codecCtx->pix_fmt;
    frame->pts = 0;
    
    result = av_image_alloc(frame->data,
                            frame->linesize,
                            frame->width,
                            frame->height,
                            frame->format,
                            1);
    if (result < 0) {
        fprintf(stderr, "Error: could not get AVFrame buffer.\n");
        return -1;
    }
    
    return 0;
}

- (int32_t)encoding {
    int result = 0;
    size_t readSize = 0;
    memset(frame->data[0], 0, perImgSize);
    do {
        readSize = fread(frame->data[0], 1, perImgSize, inputFile);
        if (readSize <= 0) {
            break;
        }
        // 设置帧的序号
        frame->pts += 1;
        result = [self encodeFrame:NO];
        if (result < 0) {
            fprintf(stderr, "Error: encodeFrame failed.\n");
            return result;
        }
    } while (readSize > 0);
    
    
    // 冲刷缓冲区
    result = [self encodeFrame:YES];
    if (result < 0) {
        fprintf(stderr, "Error: flushing failed.\n");
        return result;
    }

    // 2318790
    [Tool fileSizeIn:[Tool fetchH264FilePath]];
    return 0;
}

- (int32_t)encodeFrame:(BOOL)flushing {
    int32_t result = 0;
    if (!flushing) {
        printf("Send frame to encoder with pts: %lld.\n", frame->pts);
    }

    result = avcodec_send_frame(codecCtx, flushing ? NULL : frame);
    if (result < 0) {
        fprintf(stderr, "Error: avcodec_send_frame failed.\n");
        return result;
    }

    while (result >= 0) {
        result = avcodec_receive_packet(codecCtx, pkt);
        if (result == AVERROR(EAGAIN) || result == AVERROR_EOF) {
            return 0;
        } else if (result < 0) {
            fprintf(stderr, "Error: avcodec_receive_packet failed.\n");
            return result;
        }

        if (flushing) {
            printf("Flushing:\n");
        }
        NSLog(@"编码到第：%d帧", ++frameIndex);
        printf("Got encoded package with dts: %lld, pts: %lld.\n", pkt->dts, pkt->pts);
        [self writePacketToFile:pkt];
        av_packet_unref(pkt);
    }
    return 0;
}

/// 将编码后的数据写入到文件中
/// @param pkt 码流包
- (void)writePacketToFile:(AVPacket *)pkt {
    fwrite(pkt->data, 1, pkt->size, outputFile);
}

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
- (void)destoryVideoEncoder {
    // 释放编码器上下文结构
    avcodec_free_context(&codecCtx);
    // 释放 Frame 和 Packet 结构
    av_frame_free(&frame);
    av_packet_free(&pkt);
}

/// 打开文件
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

// 检查编码器是否支持采样格式pixFmt
- (int)checkPixFmt:(const AVCodec *)codec fmt:(enum AVPixelFormat)pixFmt {
    const enum AVPixelFormat *p = codec->pix_fmts;
    while (*p != AV_PIX_FMT_NONE) {
        if (*p == pixFmt) return 1;
        p++;
    }
    return 0;
}

/*****************************End****************************/
- (void)startEncode {
    // 先清空文件
    NSString *encodeFiles = [[Tool getLibraryCachesPath] stringByAppendingPathComponent:@"EncodeFiles"];
    [Tool deleteAllFileAtPath:encodeFiles];

    VideoEncodeSpec input;
    input.filename = [[[NSBundle mainBundle] pathForResource:@"encode.yuv" ofType:nil] UTF8String];
    input.pixFmt = AV_PIX_FMT_YUV420P;
    input.fps = 25;
    input.width = 1920;
    input.height = 1080;

    const char *outFilename = [[Tool creatH264FilePath] UTF8String];
    [self yuvEncode:&input outFilename:outFilename];
}

- (void)yuvEncode:(VideoEncodeSpec * _Nullable)input outFilename:(const char *)outFilename {
    // 编码器
    AVCodec *codec = nil;
    // 编码上下文
    __block AVCodecContext *ctx = nil;
    // 用来存放编码前的数据(yuv)
    __block AVFrame *frame = nil;
    // 用来存放编码后的数据(h264)
    __block AVPacket *pkt = nil;
    
    // 1920x1080x1.5 = 3110400
    int imgSize = av_image_get_buffer_size(input->pixFmt, input->width, input->height, 1);
    NSLog(@"imgSize: %d", imgSize);
    // 返回结果
    __block int ret = 0;
    
    // 输入文件
    FILE *inFile = fopen(input->filename, "rb");
    // 输出文件
    FILE *outFile = fopen(outFilename, "wb");
    if (!inFile || !outFile) {
        NSLog(@"file open error.");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        return;
    }
    
    // 获取 libx264 编码器
    codec = avcodec_find_encoder_by_name("libx264");
    if (!codec) {
        NSLog(@"avcodec_find_encoder_by_name error.");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        return;
    }
    
    // 检查像素格式
    if (!check_pix_fmt(codec, input->pixFmt)) {
        NSLog(@"Encoder does not support pixel format:");
        NSLog(@"%s", av_get_pix_fmt_name(input->pixFmt));
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        return;
    }
    
    // 创建上下文
    ctx = avcodec_alloc_context3(codec);
    if (!ctx) {
        NSLog(@"avcodec_alloc_context3 error.");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        return;
    }
    // 设置yuv参数
    ctx->width = input->width;
    ctx->height = input->height;
    ctx->pix_fmt = input->pixFmt;
    // 设置帧率
    ctx->time_base = (AVRational){1, input->fps};
    ctx->framerate = (AVRational){input->fps, 1};
    ctx->bit_rate = 2000000;
    ctx->gop_size = 10;
    ctx->max_b_frames = 3;
    ctx->profile = FF_PROFILE_H264_HIGH;
    
    if (codec->id == AV_CODEC_ID_H264) {
        av_opt_set(ctx->priv_data, "preset", "slow", 0);
    }
    // 打开编码器
    ret = avcodec_open2(ctx, codec, NULL);
    if (ret < 0) {
        ERROR_BUF(ret);
        NSLog(@"avcodec_open2 error");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        
        // 释放资源
        avcodec_free_context(&ctx);
        return;
    }
    
    // 创建 AVFrame
    frame = av_frame_alloc();
    if (!frame) {
        NSLog(@"av_frame_alloc error");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        
        // 释放资源
        avcodec_free_context(&ctx);
        return;
    }
    
    frame->width = ctx->width;
    frame->height = ctx->height;
    frame->format = ctx->pix_fmt;
    frame->pts = 0;
    // 创建缓冲区
    NSLog(@"frame->linesize: %lu", sizeof(frame->linesize));
    ret = av_image_alloc(frame->data,
                         frame->linesize,
                         input->width,
                         input->height,
                         input->pixFmt,
                         1);
    if (ret < 0) {
        NSLog(@"av_image_alloc error.");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        
        // 释放资源
        av_frame_free(&frame);
        avcodec_free_context(&ctx);
        return;
    }
    
    // 创建 AVPacket
    pkt = av_packet_alloc();
    pkt->data = NULL;
    pkt->size = 0;
    if (!pkt) {
        NSLog(@"av_packet_alloc error.");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        
        // 释放资源
        if (frame) {
            av_frame_free(&frame);
            av_freep(frame->data[0]);
        }
        avcodec_free_context(&ctx);
        return;
    }
    
    // 读取数据到 frame
    dispatch_queue_global_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        /*
         ptr -- 这是指向带有最小尺寸 size*nmemb 字节的内存块的指针。
         size -- 这是要读取的每个元素的大小，以字节为单位。
         nmemb -- 这是元素的个数，每个元素的大小为 size 字节。
         stream -- 这是指向 FILE 对象的指针，该 FILE 对象指定了一个输入流。
         */
        memset(frame->data[0], 0, imgSize);
        while ((ret = fread(frame->data[0], 1, imgSize, inFile) > 0)) {
            // 编码
            if (encode(ctx, frame, pkt, outFile) < 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"dispatch_async---------");
                    // 关闭文件
                    fclose(inFile);
                    fclose(outFile);
                    
                    // 释放资源
                    if (frame) {
                        av_frame_free(&frame);
                        av_freep(frame->data[0]);
                    }
                    av_packet_free(&pkt);
                    avcodec_free_context(&ctx);
                });
            }
            
            // 设置帧的序号
            frame->pts++;
        }
        
        NSLog(@"while 循环结束 - fclose");
        // 冲刷编码器
        ret = encode(ctx, NULL, pkt, outFile);
        NSLog(@"flush编码器");
        [Tool fileSizeIn:[Tool fetchH264FilePath]];
    });
}

static int frameIndex = 0;
// 编码
static int encode(AVCodecContext *ctx,
                  AVFrame *frame,
                  AVPacket *pkt,
                  FILE *outFile) {
    // 将 frame 中的数据发送到编码器， frame 为 NULL 是冲刷编码器
    int ret = avcodec_send_frame(ctx, frame);
    if (ret < 0) {
        NSLog(@"avcodec_send_frame error.");
        return ret;
    }
 
    while (true) {
        // 从编码器中获取编码后的数据
        ret = avcodec_receive_packet(ctx, pkt);
        // AVERROR(EAGAIN): 编码器还没有完成对新的1帧的编码，应该继续通过函数 avcodec_send_frame 传入后续的图像
        // AVERROR_EOF: 编码器已经完全输出内部的数据，编码完成
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            return 0;
        } else if (ret < 0) { // 出现了其他错误
            NSLog(@"avcodec_receive_packet error.");
            return ret;
        }
 
        NSLog(@"编码到第：%d帧", ++frameIndex);
        fwrite(pkt->data, 1, pkt->size, outFile);
        // 释放pkt内部指向的资源
        av_packet_unref(pkt);
    }
}

// 检查编码器是否支持采样格式pix_fmt
static int check_pix_fmt(const AVCodec *codec,
                         enum AVPixelFormat pix_fmt) {
    const enum AVPixelFormat *p = codec->pix_fmts;
    while (*p != AV_PIX_FMT_NONE) {
//        NSLog(@"AVPixelFormat: %s, %d", av_get_pix_fmt_name(*p), *p);
        if (*p == pix_fmt) return 1;
        p++;
    }
    return 0;
}


@end

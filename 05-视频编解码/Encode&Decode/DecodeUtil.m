//
//  DecodeUtil.m
//  YUVToH264
//
//  Created by Du on 2022/3/17.
//

#import "DecodeUtil.h"
// 输入缓冲区大小
#define IN_BUF_SIZE 4096

@implementation DecodeUtil
- (void)startDecode {
    // 先清空文件
    NSString *yuvFiles = [[Tool getLibraryCachesPath] stringByAppendingPathComponent:@"RecordYUV"];
    [Tool deleteAllFileAtPath:yuvFiles];
    
    VideoDecodeSpec output;
    output.filename = [[Tool creatYUVDataFileName] UTF8String];
    
    const char *inFilename = [[[NSBundle mainBundle] pathForResource:@"decode.h264" ofType:nil] UTF8String];
    [self h264DecodeWithFilename:inFilename
                          output:&output];
    
    NSLog(@"视频宽：%d", output.width);
    NSLog(@"视频高：%d", output.height);
    NSLog(@"像素格式：%s", av_get_pix_fmt_name(output.pixFmt));
    NSLog(@"帧率：%d", output.fps);
}

- (void)h264DecodeWithFilename:(const char *)inFilename output:(VideoDecodeSpec * _Nullable)output {
    // 存放h264文件数据
    char inDataArray[IN_BUF_SIZE + AV_INPUT_BUFFER_PADDING_SIZE];
    char *inData = inDataArray;
    
    // 每次读取 h264 文件的长度（也是在输入缓冲区中，剩下那些还没有被送到 parser 中的数据的大小）
    size_t dataSize;
    int isEnd = 0;
    // 解码器
    AVCodec *codec = NULL;
    // 解码上下文
    AVCodecContext *ctx = NULL;
    // 解析器上下文
    AVCodecParserContext *parserCtx = NULL;
    // 用来存放编码后的数据(yuv)
    AVFrame *frame = NULL;
    // 用来存放编码前的数据(h264)
    AVPacket *pkt = NULL;
    
    // 返回结果
    int ret = 0;
    
    // 输入文件
    FILE *inFile = fopen(inFilename, "rb");
    // 输出文件
    FILE *outFile = fopen(output->filename, "wb");
    if (!inFile || !outFile) {
        NSLog(@"file open error");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        return;
    }
    
    // 获取解码器
    codec = avcodec_find_decoder(AV_CODEC_ID_H264);
    if (!codec) {
        NSLog(@"decoder not found");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        return;
    }
    
    // 初始化解析起上下文
    parserCtx = av_parser_init(codec->id);
    if (!parserCtx) {
        NSLog(@"av_parser_init failed");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        return;
    }
    
    // 创建解码上下文
    ctx = avcodec_alloc_context3(codec);
    if (!ctx) {
        NSLog(@"avcodec_alloc_context3 failed");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        // 回收资源
        av_parser_close(parserCtx);
        return;
    }
    
    // 创建AVPacket
    pkt = av_packet_alloc();
    if (!pkt) {
        NSLog(@"av_packet_alloc failed");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        // 回收资源
        av_parser_close(parserCtx);
        avcodec_free_context(&ctx);
        return;
    }

    // 创建AVFrame
    frame = av_frame_alloc();
    if (!frame) {
        NSLog(@"av_frame_alloc failed");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        // 回收资源
        av_parser_close(parserCtx);
        avcodec_free_context(&ctx);
        av_packet_free(&pkt);
        return;
    }

    // 打开解码器
    ret = avcodec_open2(ctx, codec, NULL);
    if (ret < 0) {
        NSLog(@"av_frame_alloc failed");
        // 关闭文件
        fclose(inFile);
        fclose(outFile);
        // 回收资源
        av_parser_close(parserCtx);
        avcodec_free_context(&ctx);
        av_packet_free(&pkt);
        av_frame_free(&frame);
        return;
    }
    
    memset(inData, 0, IN_BUF_SIZE);
    do {
        // 从文件中读取数据到 inDataArray 中
        dataSize = fread(inDataArray, 1, IN_BUF_SIZE, inFile);
        // 如果读到的数据是等于0，则表明已经读取完毕
        isEnd = !dataSize;
        
        // 每次从文件中读取数据，都需要将inData 指回 inDataArray 首元素
        inData = inDataArray;
        
        // dataSize > 0：只要输入缓冲区中还有未被解码的数据
        // isEnd: 读到了文件尾部，需要继续调用av_parser_parse2来刷新一下 parser
        while (dataSize > 0 || isEnd) {
            // 对于 parser 来说，inDataArray 是输入数据，AVPacket 是输出数据
            ret = av_parser_parse2(parserCtx,
                                   ctx,
                                   &pkt->data,
                                   &pkt->size,
                                   (uint8_t *)inData,
                                   (int)dataSize,
                                   AV_NOPTS_VALUE,
                                   AV_NOPTS_VALUE,
                                   0);
            
            if (ret < 0) {
                ERROR_BUF(ret);
                NSLog(@"av_parser_parse2 failed");
                // 关闭文件
                fclose(inFile);
                fclose(outFile);
                // 回收资源
                av_parser_close(parserCtx);
                avcodec_free_context(&ctx);
                av_packet_free(&pkt);
                av_frame_free(&frame);
                return;
            }
            
            // 跳过已经解析好的数据
            inData += ret;
            // 减去已经解析过的数据
            dataSize -= ret;
            
            NSLog(@"isEnd: %d, pkt->size: %d, ret: %d", isEnd, pkt->size, ret);
            
            // 解码
            if (pkt->size > 0 && decode(ctx, pkt, frame, outFile) < 0) {
                // 关闭文件
                fclose(inFile);
                fclose(outFile);
                // 回收资源
                av_parser_close(parserCtx);
                avcodec_free_context(&ctx);
                av_packet_free(&pkt);
                av_frame_free(&frame);
                return;
            }
            
            // h264文件已经读完
            if (isEnd) {
                NSLog(@"---------文件读取完毕");
                break;
            }
        }
    } while (!isEnd);
    
    // 冲刷缓冲区
    decode(ctx, NULL, frame, outFile);
    [Tool fileSizeIn:[Tool fetchYUVFilePath]];
    // 输出的 yuv 参数
    output->width = ctx->width;
    output->height = ctx->height;
    output->pixFmt = ctx->pix_fmt;
    output->fps = ctx->framerate.num;
}

static int frameIndex = 0;

static int decode(AVCodecContext *ctx,
                  AVPacket *pkt,
                  AVFrame *frame,
                  FILE *outFile) {
    // 发送 h264 数据发送到解码器
    int ret = avcodec_send_packet(ctx, pkt);
    if (ret < 0) {
        ERROR_BUF(ret);
        NSLog(@"avcodec_send_packet failed");
        NSString *errStr = [NSString stringWithFormat:@"%s", errbuf];
        NSLog(@"%@", errStr);
        return ret;
    }

    while (true) {
        // 获取解码后的数据
        ret = avcodec_receive_frame(ctx, frame);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            return 0;
        } else if (ret < 0) {// 其他错误
            ERROR_BUF(ret);
            NSLog(@"avcodec_receive_frame failed");
            NSString *errStr = [NSString stringWithFormat:@"%s", errbuf];
            NSLog(@"%@", errStr);
            return ret;
        }
        
        NSLog(@"解码到第：%d帧", ++frameIndex);
        /*
         从地址看出：
         frame->data[0]:0x10bcc8000
         frame->data[1]:0x10bec8000 - 0x10bcc8000 = 0x200000(DEC: 2097152) -> 按道理应该是等于 Y 平面大小
         frame->data[2]:0x10bf48000 - 0x10bec8000 = 0x80000(DEC: 524288) -> 按道理应该是等于 U 平面大小
         实际上：
         Y 平面大小：1920 *1080 *1 = 2073600
         U 平面大小：1920 *1080 *0.25 = 518400
         V 平面大小：1920 *1080 *0.25 = 518400
         总结：
         所以 frame->data 不是连续的内存空间，所以不能这样写入文件：
         int imgSize = av_image_get_buffer_size(ctx->pix_fmt, ctx->width, ctx->height, 1);
         fwrite(frame->data[0], 1, imgSize, outFile);
         */
        // 将解码后的数据写入文件
        // 写入Y平面
        fwrite(frame->data[0], 1, frame->linesize[0] * ctx->height, outFile);
        // 写入U平面
        fwrite(frame->data[1], 1, frame->linesize[1] * ctx->height >> 1, outFile);
        // 写入V平面
        fwrite(frame->data[2], 1, frame->linesize[2] * ctx->height >> 1, outFile);
    }
}
@end

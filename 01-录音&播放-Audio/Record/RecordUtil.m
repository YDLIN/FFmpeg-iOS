//
//  RecordUtil.m
//  Record & play
//
//  Created by Du on 2022/2/21.
//

#import "RecordUtil.h"

#define FMT_NAME "avfoundation"
#define DEVICE_NAME ":0"

@interface RecordUtil()
@property (nonatomic, assign) BOOL flag;
@end

@implementation RecordUtil
- (void)startRecord {
    AVInputFormat *fmt = av_find_input_format(FMT_NAME);
    if (!fmt) {
        printf("av_find_input_format error.");
        return;
    }
    
    // 3、打开设备
    // 格式上下文
    __block AVFormatContext *ctx = avformat_alloc_context();
    // 打开设备
    int ret = avformat_open_input(&ctx, DEVICE_NAME, fmt, NULL);
    if (ret < 0) {
        char errbuf[1024] = { 0 };
        av_strerror(ret, errbuf, sizeof(errbuf));
        fprintf(stderr, "Error: avformat_open_input failed: %s.\n", errbuf);
        return;
    }
    
    const char *filePath = [[Tool creatPCMDataFileName] UTF8String];
    FILE *file = fopen(filePath, "wb");
    
    // AVPacket
    __block AVPacket *pkt = av_packet_alloc();
    __block int result = 0;
    __weak typeof(self) weakSelf = self;
    dispatch_queue_global_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        while (!strongSelf.flag) {
            result = av_read_frame(ctx, pkt);
            if (result == 0) {// 读取成功
                fwrite(pkt->data, 1, pkt->size, file);
                // 释放资源
                av_packet_unref(pkt);
            } else if (result == AVERROR(EAGAIN)) {
                continue;
            } else {
                char errbuf[1024] = { 0 };
                av_strerror(result, errbuf, sizeof(errbuf));
                fprintf(stderr, "Error: av_read_frame failed: %s.\n", errbuf);
                break;
            }
        }
        
        printf("while 循环结束.\n");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            printf("dispatch_async.\n");
            // 关闭文件
            fclose(file);
            // 释放资源
            av_packet_free(&pkt);
            // 关闭设备
            avformat_close_input(&ctx);
        });
        return;
    });
}

- (void)stopRecord {
    printf("停止录音---------.\n");
    self.flag = YES;
}
@end

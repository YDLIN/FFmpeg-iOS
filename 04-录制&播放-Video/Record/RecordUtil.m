//
//  RecordUtil.m
//  FFmpeg-OC
//
//  Created by Du on 2022/2/21.
//

#import "RecordUtil.h"
#import <libavutil/imgutils.h>


#define FMT_NAME "avfoundation"
#define DEVICE_NAME "1"

static FILE *file = NULL;
static AVInputFormat *inputFmt = NULL;
static AVFormatContext *fmtCtx = NULL;
static AVCodecParameters *params = NULL;
enum AVPixelFormat pixFmt = AV_PIX_FMT_NONE;
static AVPacket *pkt = NULL;
static int sampleSize = 0;

@interface RecordUtil()
@property (nonatomic, assign) BOOL flag;
@end

@implementation RecordUtil
- (void)startRecord {
    __block int32_t result = 0;
    __weak typeof(self) weakSelf = self;
    dispatch_queue_global_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    result = [self initParams];
    if (result < 0) {
        // 关闭文件
        fclose(file);
        // 释放资源
        av_packet_free(&pkt);
        // 关闭设备
        avformat_close_input(&fmtCtx);
        return;
    }
    
    dispatch_async(queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        while (!strongSelf.flag) {
            result = av_read_frame(fmtCtx, pkt);
            if (result == 0) {
                fwrite(pkt->data, sampleSize, 1, file);
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
            avformat_close_input(&fmtCtx);
        });
        return;
    });
}

- (void)stopRecord {
    self.flag = YES;
}

- (int32_t)initParams {
    int32_t result = 0;
    inputFmt = av_find_input_format(FMT_NAME);
    if (!inputFmt) {
        fprintf(stderr, "Error: can not find: %s.\n", FMT_NAME);
        return -1;
    }
    
    // 3、打开设备，设置相关的参数
    fmtCtx = avformat_alloc_context();
    AVDictionary *options = NULL;
    av_dict_set(&options, "video_size", "1280x720", 0);
    av_dict_set(&options, "pixel_format", "nv12", 0);
    av_dict_set(&options, "framerate", "30", 0);
    result = avformat_open_input(&fmtCtx, DEVICE_NAME, inputFmt, &options);
    av_dict_free(&options);
    if (result < 0) {
        fprintf(stderr, "Error: avformat_open_input failed.\n");
        return result;
    }
    
    // 4、采集数据，并将数据存到文件中
    result = [self openFile:[[Tool creatYUVDataFileName] UTF8String] isRead:NO];
    if (result < 0) {
        return result;
    }
    
    // 计算一帧的大小
    params = fmtCtx->streams[0]->codecpar;
    pixFmt = (enum AVPixelFormat)params->format;
    sampleSize = av_image_get_buffer_size(pixFmt, params->width, params->height, 1);
    
    // AVPacket
    pkt = av_packet_alloc();
    
    return 0;
}

- (int32_t)openFile:(const char *)fileName isRead:(BOOL)isRead {
    if (strlen(fileName) == 0) {
        fprintf(stderr, "Error: file is empty.\n");
        return -1;
    }
    
    [self closeFiles];
    
    file = isRead ? fopen(fileName, "rb") : fopen(fileName, "wb");
    
    if (file == NULL) {
        fprintf(stderr, "Error: failed to open file.\n");
        return -1;
    }
    return 0;
}

- (void)closeFiles {
    if (file) {
        fclose(file);
        file = NULL;
    }
}
@end

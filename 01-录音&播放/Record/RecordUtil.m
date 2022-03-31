//
//  RecordUtil.m
//  Record & play
//
//  Created by Du on 2022/2/21.
//

#import "RecordUtil.h"
#import "Tool.h"

#define FMT_NAME "avfoundation"
#define DEVICE_NAME ":0"

@interface RecordUtil()
@property (nonatomic, assign) BOOL flag;
@end

@implementation RecordUtil
- (void)startRecord {
    AVInputFormat *fmt = av_find_input_format(FMT_NAME);
    if (!fmt) {
        NSLog(@"找不到输入格式");
        return;
    }
    
    // 3、打开设备
    // 格式上下文
    __block AVFormatContext *ctx = avformat_alloc_context();
    // 打开设备
    int ret = avformat_open_input(&ctx, DEVICE_NAME, fmt, NULL);
    if (ret < 0) {
        char errbuf[1024] = {0};
        av_strerror(ret, errbuf, sizeof(errbuf));
        NSString *errorInfo = [NSString stringWithFormat:@"%s", errbuf];
        NSLog(@"打开设备失败: %@", errorInfo);
        return;
    }
    
    // 4、采集数据，并将数据存到文件中
    const char *filePath = [[Tool creatPCMDataFileName] UTF8String];
    /*
     "r"->read: 为输入操作打开文件，文件必须存在。
     "w"->write: 为输出操作创建一个空文件，如果文件已存在，则将已有文件内容舍弃，按照空文件对待。
     "a"->append: 为输出打开文件，输出操作总是再文件末尾追加数据，如果文件不存在，创建新文件。
     "r+"->read/update: 为更新打开文件（输入和输出），文件必须存在
     "w+"->write/update: 为输入和输出创建一个空文件，如果文件已存在，则将已有文件内容舍弃，按照空文件对待。
     "a+"->append/update: 为输出打开文件，输出操作总是再文件末尾追加数据，如果文件不存在，创建新文件。
     ps:表中指定的模式都是以文本的方式打开文件，如果要以二进制形式打开，需要在模式中加上“b”，既可以在模式字符串的末尾（如"rb+"），
     也可以在两个字符中间（如"r+b")。
     */
    FILE *fp = fopen(filePath, "wb");
    
    // 数据包
    __block AVPacket *pkt = av_packet_alloc();
    __block int result = 0;
    __weak typeof(self) weakSelf = self;
    dispatch_queue_global_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        while (!strongSelf.flag) {
            result = av_read_frame(ctx, pkt);
            if (result == 0) {// 读取成功
                /*
                 将数据写入文件
                 （1）buffer：是一个指针，对fwrite来说，是要获取数据的地址；
                 （2）size：要写入内容的单字节数；
                 （3）count:要进行写入size字节的数据项的个数；
                 （4）stream:目标文件指针；
                 （5）返回实际写入的数据项个数count。
                 */
                size_t wCount = fwrite(pkt->data, 1, pkt->size, fp);
                NSLog(@"读取数据成功：%zu", wCount);
                // 释放资源
                av_packet_unref(pkt);
            } else if (result == AVERROR(EAGAIN)) {
                continue;
            } else {
                char errbuf[1024] = {0};
                av_strerror(ret, errbuf, sizeof(errbuf));
                NSString *errStr = [NSString stringWithFormat:@"%s", errbuf];
                NSLog(@"读取数据失败：%@", errStr);
                break;
            }
        }
        
        NSLog(@"while 循环结束 - fclose");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"dispatch_async---------");
            // 关闭文件
            fclose(fp);
            // 释放资源
            av_packet_free(&pkt);
            // 关闭设备
            avformat_close_input(&ctx);
        });
        return;
    });
}

- (void)stopRecord {
    NSLog(@"停止录音---------");
    self.flag = YES;
}
@end

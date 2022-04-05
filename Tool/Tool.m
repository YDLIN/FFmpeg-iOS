//
//  Tool.m
//  Record
//
//  Created by Du on 2022/2/22.
//

#import "Tool.h"

@implementation Tool
+ (NSString *)getLibraryCachesPath {
    NSString *LibraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *cachesPath = [LibraryPath stringByAppendingPathComponent:@"Caches"];
    return  cachesPath;
}

+ (NSString *)creatPCMDataFileName {
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM_dd_hh_mm_ss"];
    NSString *dateString = [dateFormatter stringFromDate:currentDate];
    NSString *pathString = [NSString stringWithFormat:@"%@/PCMFiles", [Tool getLibraryCachesPath]];
    NSFileManager *fileManager= [NSFileManager defaultManager];
    //创建文件夹
    if(![fileManager fileExistsAtPath:pathString]) {
        [fileManager createDirectoryAtPath:pathString withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *fileString = [NSString stringWithFormat:@"%@.pcm", dateString];
    pathString= [pathString stringByAppendingPathComponent:fileString];
    [fileManager createFileAtPath:pathString contents:nil attributes:nil];
    return pathString;
}

+ (NSString *)creatAACDataFileName {
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM_dd_hh_mm_ss"];
    NSString *dateString = [dateFormatter stringFromDate:currentDate];
    NSString *pathString = [NSString stringWithFormat:@"%@/AACFiles", [Tool getLibraryCachesPath]];
    NSFileManager *fileManager= [NSFileManager defaultManager];
    //创建文件夹
    if(![fileManager fileExistsAtPath:pathString]) {
        [fileManager createDirectoryAtPath:pathString withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *fileString = [NSString stringWithFormat:@"%@.aac", dateString];
    pathString= [pathString stringByAppendingPathComponent:fileString];
    [fileManager createFileAtPath:pathString contents:nil attributes:nil];
    return pathString;
}

+ (NSString *)creatYUVDataFileName {
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM_dd_hh_mm_ss"];
    NSString *dateString = [dateFormatter stringFromDate:currentDate];
    
    NSString *pathString = [NSString stringWithFormat:@"%@/YUVFiles", [Tool getLibraryCachesPath]];
    NSFileManager *fileManager= [NSFileManager defaultManager];
    //创建文件夹
    if(![fileManager fileExistsAtPath:pathString]) {
        [fileManager createDirectoryAtPath:pathString withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *fileString = [NSString stringWithFormat:@"%@.yuv", dateString];
    pathString= [pathString stringByAppendingPathComponent:fileString];
    [fileManager createFileAtPath:pathString contents:nil attributes:nil];
    
    return pathString;
}

+ (NSString *)creatH264FilePath {
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM_dd_hh_mm_ss"];
    NSString *dateString = [dateFormatter stringFromDate:currentDate];
    
    NSString *pathString = [NSString stringWithFormat:@"%@/H264Files", [Tool getLibraryCachesPath]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //创建文件夹
    if(![fileManager fileExistsAtPath:pathString]) {
        [fileManager createDirectoryAtPath:pathString withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *fileString = [NSString stringWithFormat:@"%@.h264", dateString];
    pathString= [pathString stringByAppendingPathComponent:fileString];
    [fileManager createFileAtPath:pathString contents:nil attributes:nil];
    
    return pathString;
}

+ (NSString *)fetchPCMFilePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *pcmComponent = [[Tool getLibraryCachesPath] stringByAppendingPathComponent:@"PCMFiles"];
    NSArray *files = [fileManager subpathsAtPath:pcmComponent];
    files = [files sortedArrayUsingSelector:@selector(compare:)];
    NSString *pcmFilePath = @"";
    for (int i = 0; i < files.count; i++) {
        NSString *filename = files[i];
//        NSLog(@"fetchPCMFilePath: %@", filename);
        pcmFilePath = [pcmComponent stringByAppendingPathComponent:filename];
//        break;
    }
    
    NSLog(@"PCM Path: %@", pcmFilePath);
    return pcmFilePath;
}

+ (NSString *)fetchYUVFilePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *yuvComponent = [[Tool getLibraryCachesPath] stringByAppendingPathComponent:@"YUVFiles"];
    NSArray *files = [fileManager subpathsAtPath:yuvComponent] ;
    files = [files sortedArrayUsingSelector:@selector(compare:)];
    NSString *yuvFilePath = @"";
    for (int i = 0; i < files.count; i++) {
        NSString *filename = files[i];
        NSLog(@"fetchYUVFilePath: %@", filename);
        yuvFilePath = [yuvComponent stringByAppendingPathComponent:filename];
//        break;
    }
    
    NSLog(@"YUV Path: %@", yuvFilePath);
    return yuvFilePath;
}

/// 获取 H264 文件路径
+ (NSString *)fetchH264FilePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *h264Component = [[Tool getLibraryCachesPath] stringByAppendingPathComponent:@"H264Files"];
    NSArray *files = [fileManager subpathsAtPath:h264Component] ;
    files = [files sortedArrayUsingSelector:@selector(compare:)];
    NSString *h264FilePath = @"";
    for (int i = 0; i < files.count; i++) {
        NSString *filename = files[i];
        NSLog(@"fetchH264FilePath: %@", filename);
        h264FilePath = [h264Component stringByAppendingPathComponent:filename];
    }
    
    NSLog(@"H264 Path: %@", h264FilePath);
    return h264FilePath;
}

+ (void)showSpec:(AVFormatContext *)ctx {
    // 获取输入流
    AVStream *stream = ctx->streams[0];
    // 获取音频参数
    AVCodecParameters *params = stream->codecpar;
    // 声道数
    NSLog(@"声道数:%d", params->channels);
    // 采样率
    NSLog(@"采样率:%d", params->sample_rate);
    // 采样格式
    NSLog(@"采样格式:%d", params->format);
    // 每一个样本的一个声道占用多少个字节
    NSLog(@"每一个样本的一个声道占用多少个字节:%d", av_get_bytes_per_sample((enum AVSampleFormat)params->format));
    // 编码ID（可以看出采样格式）
    NSLog(@"编码ID:%u", params->codec_id);
    // 每一个样本的一个声道占用多少位（这个函数需要用到avcodec库）
    int bits = av_get_bits_per_sample(params->codec_id);
    NSLog(@"每一个样本的一个声道占用多少位:%d", bits);
    NSLog(@"每一个样本的一个声道占用多少个字节:%d", bits >> 3);
}

+ (void)deleteAllFileAtPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:nil];
    NSEnumerator *enumerator = [contents objectEnumerator];
    NSString *filename;
    while ((filename = [enumerator nextObject])) {
        [fileManager removeItemAtPath:[path stringByAppendingPathComponent:filename] error:nil];
    }
}

+ (void)showDeviceInfo {
    avdevice_register_all();
    AVFormatContext *pFormatCtx = avformat_alloc_context();
    AVDictionary *options = NULL;
    av_dict_set(&options, "list_devices", "true", 0);
    AVInputFormat *iformat = av_find_input_format("avfoundation");
    printf("==AVFoundation Device Info===\n");
    avformat_open_input(&pFormatCtx, "", iformat, &options);
    printf("=============================\n");
    if (avformat_open_input(&pFormatCtx, "1", iformat, NULL) != 0){
        printf("Couldn't open input stream.\n");
        avformat_close_input(&pFormatCtx);
        return ;
    }
}

+ (void)fileSizeIn:(NSString *)path {
    if (path.length == 0) {
        NSLog(@"path is empty");
        return;
    }
    NSFileManager* manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:path]) {
        NSLog(@"File size: %llu bytes", [[manager attributesOfItemAtPath:path error:nil] fileSize]);
    }
}
@end

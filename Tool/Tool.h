//
//  Tool.h
//  Record
//
//  Created by Du on 2022/2/22.
//

#import <Foundation/Foundation.h>
// 设备相关 API
#import <libavdevice/avdevice.h>
// 格式相关 API
#import <libavformat/avformat.h>
// 工具相关 API（比如错误处理）
#import <libavutil/avutil.h>
// 编码相关 API
#import <libavcodec/avcodec.h>
#import <libavfilter/avfilter.h>
#import "libavutil/samplefmt.h"

#define ERROR_BUF(ret) \
    char errbuf[1024]; \
    av_strerror(ret, errbuf, sizeof (errbuf));

NS_ASSUME_NONNULL_BEGIN

@interface Tool : NSObject
/// 获取 Library Caches 路径
+ (NSString *)getLibraryCachesPath;
/// pcm 的存放路径及文件名
+ (NSString *)creatPCMDataFileName;
/// aac 的存放路径及文件名
+ (NSString *)creatAACDataFileName;
/// yuv 的存放路径及文件名
+ (NSString *)creatYUVDataFileName;
/// 编码后的h264文件名路径
+ (NSString *)creatEncodeFilePath;
/// 获取 PCM 文件路径
+ (NSString *)fetchPCMFilePath;
/// 获取 YUV 文件路径
+ (NSString *)fetchYUVFilePath;
/// 获取 H264 文件路径
+ (NSString *)fetchH264FilePath;
/// 删除 path 路径下的全部文件
+ (void)deleteAllFileAtPath:(NSString *)path;
/// 从AVFormatContext中获取录音设备的相关参数
+ (void)showSpec:(AVFormatContext *)ctx;
/// 获取设备参数
+ (void)showDeviceInfo;
@end

NS_ASSUME_NONNULL_END

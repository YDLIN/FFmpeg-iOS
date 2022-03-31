//
//  ResampleUtil.h
//  PCMEncode
//
//  Created by Du on 2022/3/29.
//

#import <Foundation/Foundation.h>
#import "Tool.h"

NS_ASSUME_NONNULL_BEGIN

@interface ResampleUtil : NSObject
/// PCM 重采样(输入文件支持 planar 跟 packed，但是重采样后，文件跟命令行大小不一致)
/// @param inFName 原 PCM 文件路径
/// @param outFName 重采样后的文件路径
- (void)swrContext:(NSString *)inFName outFile:(NSString *)outFName;
@end

NS_ASSUME_NONNULL_END

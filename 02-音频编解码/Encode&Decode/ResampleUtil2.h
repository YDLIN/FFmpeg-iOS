//
//  ResampleUtil2.h
//  PCMEncode
//
//  Created by Du on 2022/3/30.
//

#import <Foundation/Foundation.h>
#import "Tool.h"

NS_ASSUME_NONNULL_BEGIN

@interface ResampleUtil2 : NSObject
/// /// PCM 重采样(输入文件不支持 planar，但是重采样后，文件跟命令行大小一致)
/// @param inFName 原 PCM 文件路径
/// @param outFName 重采样后的文件路径
- (void)swrContext:(NSString *)inFName outFile:(NSString *)outFName;
@end

NS_ASSUME_NONNULL_END

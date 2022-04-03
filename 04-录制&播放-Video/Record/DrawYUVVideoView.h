//
//  DrawYUVVideo.h
//  Record & Play
//
//  Created by Du on 2022/3/12.
//

#import "EAGLView.h"

NS_ASSUME_NONNULL_BEGIN
// 在四边形内播放 YUV 视频
@interface DrawYUVVideoView : EAGLView
- (void)playYuv:(NSString *)filePath;
- (void)stop;
@end

NS_ASSUME_NONNULL_END

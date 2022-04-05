//
//  EncodeUtil.h
//  YUVToH264
//
//  Created by Du on 2022/3/16.
//

#import <Foundation/Foundation.h>
#import "Tool.h"


NS_ASSUME_NONNULL_BEGIN

typedef struct {
    const char *filename;// 文件名
    int width; // 宽
    int height; // 高
    enum AVPixelFormat pixFmt;// 像素格式
    int fps;// 帧率
} VideoEncodeSpec;

@interface EncodeUtil : NSObject
- (void)startEncode;
- (void)startEncode2;
@end

NS_ASSUME_NONNULL_END

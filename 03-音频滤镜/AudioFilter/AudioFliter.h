//
//  AudioFliter.h
//  Encode&Decode
//
//  Created by Du on 2022/4/1.
//

#import <Foundation/Foundation.h>
#import "Tool.h"

NS_ASSUME_NONNULL_BEGIN

@interface AudioFliter : NSObject
- (void)addFilterWithSrc:(const char *)srcFileName dst:(const char *)dstFileName factor:(char *)volumeFactor;
@end

NS_ASSUME_NONNULL_END

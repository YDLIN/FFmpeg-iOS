//
//  EAGLView.h
//  Record & Play
//
//  Created by Du on 2022/3/10.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/ES3/gl.h>

NS_ASSUME_NONNULL_BEGIN

@interface EAGLView : UIView
// 绘图上下文
@property(strong, nonatomic) EAGLContext *eaglContext;
// 展示图层
@property(strong, nonatomic) CAEAGLLayer *eaglLayer;
// 渲染缓冲区
@property(assign, nonatomic) GLuint colorBuffer;
// 帧缓冲区
@property(assign, nonatomic) GLuint frameBuffer;
// 着色器句柄
@property(assign, nonatomic) GLuint program;
/// 清屏
- (void)clearScreen;
/// 编译着色器
/// @param shaderVertex 顶点着色器
/// @param shaderFragment 片段着色器
- (GLuint)compileShaders:(NSString *)shaderVertex
          shaderFragment:(NSString *)shaderFragment;

/// 清除帧缓冲区对象
- (void)deleteFrameBuffers;
@end

NS_ASSUME_NONNULL_END

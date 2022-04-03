//
//  EAGLView.m
//  Record & Play
//
//  Created by Du on 2022/3/10.
//

#import "EAGLView.h"

@implementation EAGLView
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setUp];
    }
    return self;
}

- (void)clearScreen {}

- (void)setUp {
    [self setContentScaleFactor:[[UIScreen mainScreen] scale]];
    
    [self setupContext];
    [self setupLayer];
    [self cleanBuffer];
    [self setupRenderBuffer];
    [self setupFrameBuffer];
    
    // 清屏
    [self clearScreen];
    // 渲染 _colorBuffer 中的图像到 _eaglLayer 中
    [_eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

// 上下文
- (void)setupContext {
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:_eaglContext];
}

// 图层
- (void)setupLayer {
    _eaglLayer = (CAEAGLLayer *)self.layer;
    _eaglLayer.frame = self.frame;
    // 设置不透明，提高性能
    _eaglLayer.opaque = YES;
    // 设置颜色缓冲区格式等
    NSDictionary *properties = @{kEAGLDrawablePropertyRetainedBacking:
                                     [NSNumber numberWithBool:YES],
                                 kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
    };
    _eaglLayer.drawableProperties = properties;
}

- (void)setupRenderBuffer {
    // 创建 _colorBuffer，用来存储将要绘制到屏幕上的图像
    glGenRenderbuffers(1, &_colorBuffer);
    // 绑定 _colorBuffer 到 GL_RENDERBUFFER 目标上
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBuffer);
    // 为 _colorBuffer 分配存储空间，并绑定到 _eaglLayer 上（drawable设置为 nil 可以解绑）
    BOOL allocStorage = [_eaglContext renderbufferStorage:GL_RENDERBUFFER
                                             fromDrawable:_eaglLayer];
    if (!allocStorage) {
        NSAssert(YES, @"%s %d %@", __func__, __LINE__, @"渲染缓冲区分配内存失败");
    }
}

- (void)setupFrameBuffer {
    // 创建 _frameBuffer, 保存绘制时的一些信息
    glGenFramebuffers(1, &_frameBuffer);
    // 绑定 _frameBuffer 到 GL_FRAMEBUFFER 目标上
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    // 将 _colorBuffer 和 _frameBuffer 绑定，并附着到 GL_COLOR_ATTACHMENT0 上
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER,
                              _colorBuffer);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSAssert(YES, @"%s %d %@ 0x%x", __func__, __LINE__, @"创建帧缓冲区失败", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
}

- (void)cleanBuffer {
    // 清空缓冲区
    glDeleteBuffers(1, &_colorBuffer);
    _colorBuffer = 0;
    glDeleteBuffers(1, &_frameBuffer);
    _frameBuffer = 0;
}

- (GLuint)compileShaders:(NSString *)shaderVertex
          shaderFragment:(NSString *)shaderFragment {
    // 1、编译vertex 和 fragment着色器
    GLuint vertexShader = [self compileShader:shaderVertex withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:shaderFragment withType:GL_FRAGMENT_SHADER];
    
    // 2、创建程序对象
    GLuint glProgram = glCreateProgram();
    // 将两个 shader 绑定到程序对象(glDetachShader可以解绑)
    glAttachShader(glProgram, vertexShader);
    glAttachShader(glProgram, fragmentShader);
    // 将 vertex 和 fragment shader 创建成一个可执行文件，分别在顶点处理器和片段处理器上运行
    glLinkProgram(glProgram);
    
    // 检查链接情况
    GLint linkParams;
    glGetProgramiv(glProgram, GL_LINK_STATUS, &linkParams);
    if (linkParams == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(glProgram, sizeof(messages), 0, &messages[0]);
        NSLog(@"链接程序失败: %@", [NSString stringWithUTF8String:messages]);
        exit(1);
    }
    
    // 释放着色器
    if (vertexShader) {
        glDeleteShader(vertexShader);
    }
    if (fragmentShader) {
        glDeleteShader(fragmentShader);
    }
    
    return glProgram;
}

// 编译链接着色器
- (GLuint)compileShader:(NSString *)shaderName
               withType:(GLenum)shaderType {
    // 1、查找 shader 文件
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:shaderName ofType:nil];
    NSError *error;
    // 读取 shader 的内容为字符串
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    
    if (shaderString == nil || shaderString.length == 0) {
        NSLog(@"加载 shader 文件出错：%@", error.localizedDescription);
        exit(1);
    }
    
    // 2、创建一个代表 shader 的 OpenGL 对象（着色器句柄）, 需要指定 vertex shader 或 fragment shader等
    GLuint shaderHandle = glCreateShader(shaderType);
    
    // 3、将 shader 文件转为C字符串，作为源码传给 OpenGL
    const char *shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    // 将着色器源码附加到着色器对象上
    //参数1：着色器对象
    //参数2：传递的源码字符串数量
    //参数3：着色器源码
    //参数4：着色器源码长度
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    // 4、编译 shader
    glCompileShader(shaderHandle);
    
    // 5、检查 shader 是否编译成功
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSLog(@"编译 shader 失败: %@", [NSString stringWithUTF8String:messages]);
        exit(1);
    }
    
    return shaderHandle;
}

- (void)deleteFrameBuffers {
    glDeleteFramebuffers(1, &_frameBuffer);
}
@end

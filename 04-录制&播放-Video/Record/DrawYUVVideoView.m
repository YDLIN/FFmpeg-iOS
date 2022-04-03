//
//  DrawYUVImage.m
//  Record & Play
//
//  Created by Du on 2022/3/12.
//

#import "DrawYUVVideoView.h"
#import <OpenGLES/ES3/gl.h>


@implementation DrawYUVVideoView {
    FILE *_inFile;
    int _width;// YUV 图片宽度
    int _height;// YUV 图片高度
    uint8_t *_yuv;
    GLuint _textureY;// Y 纹理
    GLuint _textureUV;// UV 纹理
    NSTimer *_timer;// 定时器
    NSString *_filePath;// 文件路径
}

- (void)playYuv:(NSString *)filePath {
    _filePath = filePath;
    [self setupRender];
    [self setupTexture];
}

- (void)stop {
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
        [self clearScreen];
        // 渲染 _colorBuffer 中的图像到 _eaglLayer 中
        [self.eaglContext presentRenderbuffer:GL_RENDERBUFFER];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 发送通知
            [[NSNotificationCenter defaultCenter] postNotificationName:@"PlayYUVCompleted" object:nil];
        });
    }
}

- (void)clearScreen {
    glClearColor(89.0/255.0, 174.0/255.0, 196.0/255.0, 1.0);
    // 设置 _colorBuffer 中的像素颜色为上一步指定的颜色
    glClear(GL_COLOR_BUFFER_BIT);
}

- (void)setupRender {
    CGFloat scale = [UIScreen mainScreen].scale;
    NSString *frame = NSStringFromCGRect(self.frame);
    NSLog(@"frame: %@", frame);
    glViewport(0, 0, self.frame.size.width * scale, self.frame.size.height * scale);
    
    // 前3是顶点坐标，后2是纹理坐标
    GLfloat vertices[] = {
        -1.0f, -1.0f, 0.0f, 0.0f, 1.0f,// 左下角 - index 0
        1.0f, -1.0f, 0.0f, 1.0f, 1.0f,// 右下角 - index 1
        -1.0f, 1.0f, 0.0f, 0.0f, 0.0f,// 左上角 对应 纹理的原点 - index 2
        1.0f, 1.0f, 0.0f, 1.0f, 0.0f// 右上角 - index 3
    };
    
    GLuint indices[] = {
        0, 1, 2,
        1, 2, 3
    };
    
    self.program = [self compileShaders:@"drawYUVVertex.vsh"
                         shaderFragment:@"drawYUVFragment.fsh"];
    glUseProgram(self.program);
    
    // 顶点缓冲对象
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    // 将顶点数据写到vertexBuffer
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    // 索引缓冲对对象
    GLuint indexBuffer;
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    // 将顶点数据写到indexBuffer
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    // 获取 vertex 中 position 变量的引用
    GLuint positionSlot = glGetAttribLocation(self.program, "position");
    // 启用 position 变量，使其对 GPU 可以见，默认是关闭的
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot,// 属性index，给哪个属性传递信息
                          3,// position由x, y, z三个值组成
                          GL_FLOAT,// 属性的数据类型
                          GL_FALSE,// GL_FALSE表示不要将数据类型标准化
                          sizeof(GLfloat) *5,// 数组中，元素的长度
                          (void *)0);// 数组的首地址
    
    GLuint textCoordinateSlot = glGetAttribLocation(self.program, "textCoordinate");
    glEnableVertexAttribArray(textCoordinateSlot);
    glVertexAttribPointer(textCoordinateSlot,
                          2,
                          GL_FLOAT,
                          GL_FALSE,
                          sizeof(GLfloat) *5,
                          (void *)(sizeof(GLfloat) *3));
}

- (void)setupTexture {
    // 设置纹理
    [self setupTexture:&_textureY target:GL_TEXTURE0];
    [self setupTexture:&_textureUV target:GL_TEXTURE1];
    // 设置采样器
    [self setupSampler:"texture_Y" index:0];
    [self setupSampler:"texture_UV" index:1];
    [self setupSampler:"yuvType" index:1];
    // 打开文件
    [self openFileWithName:[_filePath UTF8String] fileWidth:1280 fileHeight:720];
    // 渲染
    _timer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / 30.0)
                                              target:self
                                            selector:@selector(render)
                                            userInfo:nil
                                             repeats:YES];
}

- (void)setupSampler:(const GLchar*)samplerName index:(GLint)index {
    // 获取 samplerName 采样器在 GPU 中的地址（也叫插槽）
    GLint sampler = glGetUniformLocation(self.program, samplerName);
    /*
     对 sampler 采样器进行设置（指定着色器中纹理对应哪一层纹理单元）
     location: 着色器中纹理坐标
     x: 指定哪一层纹理
     */
    glUniform1i(sampler, index);
}

- (void)openFileWithName:(const char *)inFilename fileWidth:(int)width fileHeight:(int)height {
    _inFile = fopen(inFilename, "rb");
    if (!_inFile) {
        NSLog(@"打开文件失败： %s", inFilename);
        exit(1);
    }
    
    _width = width;
    _height = height;
    
    // 一帧所需要的内存空间，格式是 NV12，所以每个像素所占用的内存是 rgb 的一半
    _yuv = calloc(_width *_height *3 / 2, 1);
    if (!_yuv) {
        NSLog(@"申请内存失败");
        exit(1);
    }
    
    // 清空_yuv
    memset(_yuv, 0, _width *_height *3 / 2);
}

- (void)render {
    int fileSize = _width *_height *3 / 2;
    //读取Y、U、V
    unsigned long count = fread(_yuv, 1, fileSize, _inFile);
    if (count <= 0) {
        [_timer invalidate];
        _timer = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            // 发送通知
            [[NSNotificationCenter defaultCenter] postNotificationName:@"PlayYUVCompleted" object:nil];
        });
        return;
    }
    
    //y
    [self loadTexture:_textureY
                width:_width
               height:_height
                  ptr:_yuv
               yPlane:NO];
    // UV
    [self loadTexture:_textureUV
                width:_width >> 1
               height:_height >> 1
                  ptr:(_yuv + _width *_height)
               yPlane:YES];
    
    // 绘制
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    // 渲染 OpenGL 绘制好的图像到 layer
    [self.eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)setupTexture:(GLuint *)texture target:(GLenum)target {
    // 创建纹理对象，n：创建数量，GLuint：纹理 ID
    glGenTextures(1, texture);
    glActiveTexture(target);
    // 绑定纹理对象 textureID 到纹理目标 GL_TEXTURE_2D
    // 接下来对纹理目标的操作都发生在此对象上
    /*
     glBindTexture可以让你创建或使用一个已命名的纹理，调用glBindTexture方法，将target设置为GL_TEXTURE_1D、GL_TEXTURE_2D、GL_TEXTURE_3D或者GL_TEXTURE_CUBE_MAP，并将texture设置为你想要绑定的新纹理的名称，即可将纹理名绑定至当前活动纹理单元目标。当一个纹理与目标绑定时，该目标之前的绑定关系将自动被打破。纹理的名称是一个无符号的整数。在每个纹理目标中，0被保留用以代表默认纹理。纹理名称与相应的纹理内容位于当前GL rendering上下文的共享对象空间中。
     */
    glBindTexture(GL_TEXTURE_2D, (*texture));
    // 纹理过滤
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);// 缩小时，线性过滤
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);// 放大时，线性过滤
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);// 水平方向 - 边缘像素延伸
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);// 垂直方向 - 边缘像素延伸
}

- (void)loadTexture:(GLuint)texture
              width:(int)width
             height:(int)height
                ptr:(uint8_t *)ptr
             yPlane:(BOOL)isYPlane {
    glBindTexture(GL_TEXTURE_2D, texture);
    
    // 根据像素数据,加载纹理
    glTexImage2D(GL_TEXTURE_2D,//指定目标纹理，这个值必须是GL_TEXTURE_2D。
                 0,//执行细节级别。0是最基本的图像级别
                 (isYPlane ? GL_LUMINANCE_ALPHA : GL_LUMINANCE) ,//指定纹理中的颜色格式。使用GL_LUMINANCE的时候，可以将Y分量存储到像素的各个通道内，这样在着色器中，我们可以通过R，G，B任意一个分量来获取到Y值。U，V分量同理
                 width,//纹理的宽度
                 height,//纹理的高度
                 0,//纹理的边框宽度,必须为0
                 (isYPlane ? GL_LUMINANCE_ALPHA : GL_LUMINANCE),//像素数据的颜色格式
                 GL_UNSIGNED_BYTE,//指定像素数据的数据类型
                 ptr);// 指向图像数据的指针
}
@end

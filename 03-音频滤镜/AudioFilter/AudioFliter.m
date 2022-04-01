//
//  AudioFliter.m
//  Encode&Decode
//
//  Created by Du on 2022/4/1.
//

#import "AudioFliter.h"
#import <libavfilter/buffersink.h>
#import <libavfilter/buffersrc.h>

#define INPUT_SAMPLERATE 44100
#define INPUT_FORMAT AV_SAMPLE_FMT_FLTP
#define INPUT_CHANNEL_LAYOUT AV_CH_LAYOUT_STEREO
#define FRAME_SIZE 4096

#define OUTPUT_SAMPLERATE 22050
#define OUTPUT_FORMAT AV_SAMPLE_FMT_S16
#define OUTPUT_CHANNEL_LAYOUT AV_CH_LAYOUT_STEREO

static AVFilterGraph *filterGraph;
static AVFilterContext *abuffersrcCtx;
static AVFilterContext *volumeCtx;
static AVFilterContext *aformatCtx;
static AVFilterContext *abuffersinkCtx;
static AVFrame *srcFrame = NULL, *dstFrame = NULL;
static FILE *srcFile = NULL;
static FILE *dstFile = NULL;

@implementation AudioFliter
- (void)addFilterWithSrc:(const char *)srcFileName dst:(const char *)dstFileName factor:(char *)volumeFactor {
    int32_t result = 0;
    result = [self opensrcfile:srcFileName dstfile:dstFileName];
    if (result < 0) {
        goto end;
    }
    
    result = [self initAudioFilter:volumeFactor];
    if (result < 0) {
        goto end;
    }
    
    result = [self audioFiltering];
    if (result < 0) {
        goto end;
    }
    
    // 打印文件大小
    [Tool fileSizeIn:[Tool fetchPCMFilePath]];
end:
    [self destoryAudioFilter];
    [self closeFiles];
}

- (int32_t)initAudioFilter:(char *)volumeFactor {
    int32_t result = 0;
    char chLayout[64];
    char optionsStr[1024];
    AVDictionary *optionsDict = NULL;
    
    // 创建滤镜图
    filterGraph = avfilter_graph_alloc();
    if (!filterGraph) {
        fprintf(stderr, "Error: Unable to create filter graph.\n");
        return AVERROR(ENOMEM);
    }

    // 创建abuffer滤镜，该滤镜为输入滤镜，不可缺少
    const AVFilter *abuffer = avfilter_get_by_name("abuffer");
    if (!abuffer) {
        fprintf(stderr, "Error: Could not find the abuffer filter.\n");
        return AVERROR_FILTER_NOT_FOUND;
    }

    // 创建滤镜实例，返回滤镜上下文
    abuffersrcCtx = avfilter_graph_alloc_filter(filterGraph, abuffer, "src");
    if (!abuffersrcCtx) {
        fprintf(stderr, "Error: Could not allocate the abuffer instance.\n");
        return AVERROR(ENOMEM);
    }

    // 为滤镜实例设置参数
    // 获取通道布局描述，如果nb_channels <= 0，则根据channel_layout来推断
    av_get_channel_layout_string(chLayout, sizeof(chLayout), 0, INPUT_CHANNEL_LAYOUT);
    av_opt_set(abuffersrcCtx, "channel_layout", chLayout, AV_OPT_SEARCH_CHILDREN);
    av_opt_set(abuffersrcCtx, "sample_fmt", av_get_sample_fmt_name(INPUT_FORMAT), AV_OPT_SEARCH_CHILDREN);
    av_opt_set_q(abuffersrcCtx, "time_base", (AVRational){1, INPUT_SAMPLERATE}, AV_OPT_SEARCH_CHILDREN);
    av_opt_set_int(abuffersrcCtx, "sample_rate", INPUT_SAMPLERATE, AV_OPT_SEARCH_CHILDREN);

    // 初始化滤镜
    result = avfilter_init_str(abuffersrcCtx, NULL);
    if (result < 0) {
        fprintf(stderr, "Error: Could not initialize the abuffer filter.\n");
        return result;
    }

    // 创建volumn滤镜
    const AVFilter *volume = avfilter_get_by_name("volume");
    if (!volume) {
        fprintf(stderr, "Error: Could not find the volumn filter.\n");
        return AVERROR_FILTER_NOT_FOUND;
    }

    volumeCtx = avfilter_graph_alloc_filter(filterGraph, volume, "volume");
    if (!volumeCtx) {
        fprintf(stderr, "Error: Could not allocate the volume instance.\n");
        return AVERROR(ENOMEM);
    }

    av_dict_set(&optionsDict, "volume", volumeFactor, 0);
    result = avfilter_init_dict(volumeCtx, &optionsDict);
//    av_opt_set(volumeCtx, "volume", volumeFactor, AV_OPT_SEARCH_CHILDREN);
//    result = avfilter_init_str(volumeCtx, NULL);
    av_dict_free(&optionsDict);
    if (result < 0) {
        fprintf(stderr, "Error: Could not initialize the volume filter.\n");
        return result;
    }

    // 创建aformat滤镜
    const AVFilter *aformat = avfilter_get_by_name("aformat");
    if (!aformat) {
        fprintf(stderr, "Error: Could not find the aformat filter.\n");
        return AVERROR_FILTER_NOT_FOUND;
    }

    aformatCtx = avfilter_graph_alloc_filter(filterGraph, aformat, "aformat");
    if (!aformatCtx) {
        fprintf(stderr, "Error: Could not allocate the aformat instance.\n");
        return AVERROR(ENOMEM);
    }

    
    /*
     按照 format 格式化成字符串
     PRIx64：用16进制表示64位无符号整数
     这一步相当于重采样了
     */
    snprintf(optionsStr,
             sizeof(optionsStr),
             "sample_fmts=%s:sample_rates=%d:channel_layouts=0x%" PRIx64,
             av_get_sample_fmt_name(OUTPUT_FORMAT),
             OUTPUT_SAMPLERATE,
             (uint64_t)OUTPUT_CHANNEL_LAYOUT);
    result = avfilter_init_str(aformatCtx, optionsStr);
    if (result < 0) {
        fprintf(stderr, "Error: Could not initialize the aformat filter.\n");
        return result;
    }

    // 创建abuffersink滤镜，该滤镜为输出滤镜，不可缺少
    const AVFilter *abuffersink = avfilter_get_by_name("abuffersink");
    if (!abuffersink) {
        fprintf(stderr, "Error: Could not find the abuffersink filter.\n");
        return AVERROR_FILTER_NOT_FOUND;
    }

    abuffersinkCtx = avfilter_graph_alloc_filter(filterGraph, abuffersink, "sink");
    if (!abuffersinkCtx) {
        fprintf(stderr, "Error: Could not allocate the abuffersink instance.\n");
        return AVERROR(ENOMEM);
    }

    result = avfilter_init_str(abuffersinkCtx, NULL);
    if (result < 0) {
        fprintf(stderr, "Error: Could not initialize the abuffersink instance.\n");
        return result;
    }

    /*
     连接滤镜，形成滤镜管道
     srcfilter-->volumefilter->aformat->....->sinkfilter
     滤镜管道必须要有一个输入滤镜(abuffer，用于接收要处理的数据),一个输出滤镜(abuffersink，用于提供处理好的数据)
     */
    result = avfilter_link(abuffersrcCtx, 0, volumeCtx, 0);
    if (result >= 0) result = avfilter_link(volumeCtx, 0, aformatCtx, 0);
    if (result >= 0) result = avfilter_link(aformatCtx, 0, abuffersinkCtx, 0);
    if (result < 0) {
        fprintf(stderr, "Error connecting filters.\n");
        return result;
    }

    // 配置滤镜图、检查其有效性
    result = avfilter_graph_config(filterGraph, NULL);
    if (result < 0) {
        fprintf(stderr, "Error: Error configuring the filter graph.\n");
        return result;
    }

    
    srcFrame = av_frame_alloc();
    if (!srcFrame) {
        fprintf(stderr, "Error: could not alloc input frame.\n");
        return -1;
    }

    dstFrame = av_frame_alloc();
    if (!dstFrame) {
        fprintf(stderr, "Error: could not alloc input frame.\n");
        return -1;
    }

    return result;
}

- (int32_t)filterFrame {
    // 添加需要处理的数据
    int32_t result = av_buffersrc_add_frame(abuffersrcCtx, srcFrame);
    if (result < 0) {
        fprintf(stderr, "Error:add frame to buffersrc failed.\n");
        return result;
    }

    while (true) {
        // 获取处理好的数据
        result = av_buffersink_get_frame(abuffersinkCtx, dstFrame);
        if (result == AVERROR(EAGAIN) || result == AVERROR_EOF) {
            return 1;
        } else if (result < 0) {
            fprintf(stderr, "Error: av_buffersink_get_frame failed.\n");
            return result;
        }
        
        [self configureDataWith:dstFrame format:dstFrame->format channels:dstFrame->channels isRead:NO];
        av_frame_unref(dstFrame);
    }
    return result;
}

- (int32_t)audioFiltering {
    int32_t result = 0;
    int channels = 0;
    while (![self endOfFile:srcFile]) {
        result = [self initFrame];
        if (result < 0) {
            fprintf(stderr, "Error: init_frame failed.\n");
            return result;
        }
        
        channels = av_get_channel_layout_nb_channels(INPUT_CHANNEL_LAYOUT);
        result = [self configureDataWith:srcFrame format:INPUT_FORMAT channels:channels isRead:YES];
        if (result < 0) {
            fprintf(stderr, "Error: configureDataWith:format:channels: failed.\n");
            return -1;
        }
        
        result = [self filterFrame];
        if (result < 0) {
            fprintf(stderr, "Error: filterFrame failed.\n");
            return -1;
        }
    }
    return result;
}

- (int32_t)initFrame {
    srcFrame->sample_rate = INPUT_SAMPLERATE;
    srcFrame->nb_samples = FRAME_SIZE;
    srcFrame->format = INPUT_FORMAT;
    srcFrame->channel_layout = INPUT_CHANNEL_LAYOUT;
    srcFrame->channels = av_get_channel_layout_nb_channels(INPUT_CHANNEL_LAYOUT);
    int32_t result = av_frame_get_buffer(srcFrame, 0);
    if (result < 0) {
        fprintf(stderr, "Error: AVFrame could not get buffer.\n");
        return -1;
    }
    return 0;
}

/// 回收资源
- (void)destoryAudioFilter {
    av_frame_free(&srcFrame);
    av_frame_free(&dstFrame);
    avfilter_graph_free(&filterGraph);
}

- (int32_t)configureDataWith:(AVFrame *)frame format:(enum AVSampleFormat)format channels:(int)channels isRead:(BOOL)isRead {
    // 单个声道一个样本的大小（假如是两声道就是一个 L，或者是一个 R）
    int singleSize = av_get_bytes_per_sample(format);
    // 所有声道单个样本的总大小（假如是两声道就是一个LR）
    int totalSize = channels *singleSize;
    if (singleSize < 0) {
        fprintf(stderr, "Error: failed to calculate data size");
        return -1;
    }
    
    if (av_sample_fmt_is_planar(format)) {
        for (int sampleIdx = 0; sampleIdx < frame->nb_samples; sampleIdx++) {
            for (int channelIdx = 0; channelIdx < channels; channelIdx++) {
                if (isRead) {
                    fread(frame->data[channelIdx] + sampleIdx *singleSize, 1, singleSize, srcFile);
                } else {
                    fwrite(frame->data[channelIdx] + sampleIdx *singleSize, 1, singleSize, dstFile);
                }
            }
        }
    } else {
        if (isRead) {
            fread(frame->data[0], 1, totalSize *frame->nb_samples, srcFile);
        } else {
            fwrite(frame->data[0], 1, totalSize *frame->nb_samples, dstFile);
        }
    }
    return 0;
}

/// 判断文件到达尾部
- (int)endOfFile:(FILE *)file {
    if (!file) {
        fprintf(stderr, "Error: file is empty.\n");
        return 1;
    }
    return feof(file);
}

/// 打开文件
- (int32_t)opensrcfile:(const char *)srcfileName dstfile:(const char *)outfileName {
    if (strlen(srcfileName) == 0 || strlen(outfileName) == 0) {
        fprintf(stderr, "Error: input or output is empty.\n");
        return -1;
    }
    [self closeFiles];
    srcFile = fopen(srcfileName, "rb");
    if (srcFile == NULL) {
        fprintf(stderr, "Error: failed to open input file.\n");
        return -1;
    }
    
    dstFile = fopen(outfileName, "wb");
    if (dstFile == NULL) {
        fprintf(stderr, "Error: failed to open output file.\n");
        return -1;
    }
    
    return 0;
}

/// 关闭文件，并清空指针
- (void)closeFiles {
    if (srcFile) {
        fclose(srcFile);
        srcFile = NULL;
    }
    
    if (dstFile) {
        fclose(dstFile);
        dstFile = NULL;
    }
}
@end

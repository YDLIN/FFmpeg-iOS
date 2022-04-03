//
//  PlayUtil.m
//  Record & play
//
//  Created by Du on 2022/2/21.
//

#import "PlayUtil.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

#define OUTPUT_BUS 0

@implementation PlayUtil {
    AudioUnit audioUnit;
    AudioBufferList *buffList;
    NSInputStream *inputStream;
}

- (void)dealloc {
    NSLog(@"dealloc ---> %@", NSStringFromClass([self class]));
    
    if (audioUnit) {
        AudioOutputUnitStop(audioUnit);
        AudioUnitUninitialize(audioUnit);
        AudioComponentInstanceDispose(audioUnit);
    }
    
    if (buffList != NULL) {
        free(buffList);
        buffList = NULL;
    }
}

- (void)play {
    [self initPlayer];
    AudioOutputUnitStart(audioUnit);
}

- (void)stop {
    AudioOutputUnitStop(audioUnit);
    if (buffList != NULL) {
        if (buffList->mBuffers[0].mData) {
            free(buffList->mBuffers[0].mData);
            buffList->mBuffers[0].mData = NULL;
        }
        free(buffList);
        buffList = NULL;
    }
    
    [inputStream close];
}

- (void)initPlayer {
    inputStream = [NSInputStream inputStreamWithFileAtPath:[Tool fetchPCMFilePath]];
    if (!inputStream) {
        fprintf(stderr, "打开 PCM 文件失败");
        return;
    }
    [inputStream open];
    
    NSError *error = nil;
    
    // 获取音频会话实例
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (error) {
        fprintf(stderr, "AVAudioSession setCategory error");
        return;
    }
    [session setActive:YES error:&error];
    if (error) {
        fprintf(stderr, "AVAudioSession setActive error");
        return;
    }
    
    [self setupAudioPlayerInstance:&error];
    if (error) {
        NSLog(@"setupAudioPlayerInstance error:%zi %@", error.code, error.localizedDescription);
    }
}

// 创建音频播放实例
- (void)setupAudioPlayerInstance:(NSError **)error {
    OSStatus status = noErr;
    // 设置音频组件描述
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    // 查找符合描述的音频组件
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    
    // 创建音频组件实例
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        return;
    }
    
    // 设置实例的读写属性
    UInt32 flag = 1;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  OUTPUT_BUS,
                                  &flag,
                                  sizeof(flag));
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        return;
    }
    
    
    // 设置音频参数等
    AudioStreamBasicDescription inputFormat;
    memset(&inputFormat, 0, sizeof(inputFormat));
    inputFormat.mSampleRate = 44100;
    inputFormat.mFormatID = kAudioFormatLinearPCM;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    inputFormat.mFramesPerPacket = 1;// 每个数据包的帧数
    inputFormat.mChannelsPerFrame = 1;
    inputFormat.mBitsPerChannel = 16;
    inputFormat.mBytesPerFrame = inputFormat.mChannelsPerFrame *inputFormat.mBitsPerChannel / 8;
    inputFormat.mBytesPerPacket = inputFormat.mFramesPerPacket *inputFormat.mBytesPerFrame;
    
    status = AudioUnitSetProperty(audioUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   OUTPUT_BUS,
                                   &inputFormat,
                                   sizeof(inputFormat));
    
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        return;
    }
    
    // 创建缓冲区
    buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    UInt32 bufSize = 1024 *2 *inputFormat.mChannelsPerFrame;
    buffList->mNumberBuffers = 1;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = bufSize;
    buffList->mBuffers[0].mData = malloc(bufSize);
    
    // 设置回调
    AURenderCallbackStruct playCallback = {
        .inputProc = PlayCallback,
        .inputProcRefCon = (__bridge void * _Nullable)(self)
    };
    
    status = AudioUnitSetProperty(audioUnit,
                                   kAudioUnitProperty_SetRenderCallback,
                                   kAudioUnitScope_Global,
                                   OUTPUT_BUS,
                                   &playCallback,
                                   sizeof(playCallback));
    
    status = AudioUnitInitialize(audioUnit);
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        return;
    }
}

static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    PlayUtil *player = (__bridge PlayUtil *)inRefCon;
    
    ioData->mBuffers[0].mDataByteSize = (UInt32)[player->inputStream read:ioData->mBuffers[0].mData
                                                                maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];;
    NSLog(@"out size: %d", ioData->mBuffers[0].mDataByteSize);
    
    if (ioData->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player stop];
        });
    }
    return noErr;
}
@end

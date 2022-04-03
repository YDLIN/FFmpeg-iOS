//
//  ViewController.m
//  FFmpeg-OC
//
//  Created by Du on 2022/2/19.
//

#import "ViewController.h"
#import "RecordUtil.h"
#import "Tool.h"
#import "DrawYUVVideoView.h"


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *recordBtn;
@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (weak, nonatomic) IBOutlet DrawYUVVideoView *playView;
@property (strong, nonatomic) RecordUtil *util;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.util = [[RecordUtil alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changedText) name:@"PlayYUVCompleted" object:nil];
}

- (IBAction)recordDidClicked:(UIButton *)sender {
    if (sender.tag == 0) {
        [self.util startRecord];
        [self.recordBtn setTitle:@"Stop" forState:UIControlStateNormal];
        sender.tag = 1;
    } else {
        [self.util stopRecord];
        [self.recordBtn setTitle:@"Record" forState:UIControlStateNormal];
        sender.tag = 0;
    }
}

- (IBAction)playDidClicked:(UIButton *)sender {
    if (sender.tag == 0) {
        [self.playView playYuv:[Tool fetchYUVFilePath]];
        [self.playBtn setTitle:@"Stop" forState:UIControlStateNormal];
        sender.tag = 1;
    } else {
        [self.playView stop];
        [self.playBtn setTitle:@"Play" forState:UIControlStateNormal];
        sender.tag = 0;
    }
}

- (void)changedText {
    [self.playBtn setTitle:@"Play" forState:UIControlStateNormal];
    self.playBtn.tag = 0;
}

@end

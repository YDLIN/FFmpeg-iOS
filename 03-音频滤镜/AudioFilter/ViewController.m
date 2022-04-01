//
//  ViewController.m
//  Encode&Decode
//
//  Created by Du on 2022/2/19.
//

#import "ViewController.h"
#import "AudioFliter.h"
#import "PlayUtil.h"


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *addFilterBtn;
@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (strong, nonatomic) AudioFliter *filterUtil;
@property (strong, nonatomic) PlayUtil *playUtil;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.filterUtil = [[AudioFliter alloc] init];
    self.playUtil = [[PlayUtil alloc] init];
}

- (IBAction)filterDidClicked:(UIButton *)sender {
    const char *srcPath = [[[NSBundle mainBundle] pathForResource:@"44100_2_f32le.pcm" ofType:nil] UTF8String];
    const char *dstPath = [[Tool creatPCMDataFileName] UTF8String];
    [self.filterUtil addFilterWithSrc:srcPath dst:dstPath factor:"0.1"];
}

- (IBAction)playDidClicked:(UIButton *)sender {
    [self.playUtil play];
}
@end

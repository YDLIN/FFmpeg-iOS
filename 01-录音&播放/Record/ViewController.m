//
//  ViewController.m
//  Record & play
//
//  Created by Du on 2022/2/19.
//

#import "ViewController.h"
#import "RecordUtil.h"
#import "PlayUtil.h"
#import "Tool.h"


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *recordBtn;
@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (strong, nonatomic) RecordUtil *util;
@property (strong, nonatomic) PlayUtil *playUtil;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.util = [[RecordUtil alloc] init];
    self.playUtil = [[PlayUtil alloc] init];
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
    [self.playUtil play];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    [self showDevice];
}

@end

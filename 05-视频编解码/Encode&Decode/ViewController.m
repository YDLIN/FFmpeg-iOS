//
//  ViewController.m
//  FFmpeg-OC
//
//  Created by Du on 2022/2/19.
//

#import "ViewController.h"
#import "EncodeUtil.h"
#import "Tool.h"
#import "DecodeUtil.h"


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *encodeBtn;
@property (weak, nonatomic) IBOutlet UIButton *decodeBtn;
@property (strong, nonatomic) EncodeUtil *encodeUtil;
@property (strong, nonatomic) DecodeUtil *decodeUtil;
@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.encodeUtil = [[EncodeUtil alloc] init];
    self.decodeUtil = [[DecodeUtil alloc] init];
}

- (IBAction)encodeBtnDidClicked:(UIButton *)sender {
    [self.encodeUtil startEncode2];
}

- (IBAction)decodeDidClicked:(UIButton *)sender {
    [self.decodeUtil startDecode];
}

@end

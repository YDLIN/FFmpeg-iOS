//
//  ViewController.m
//  Encode&Decode
//
//  Created by Du on 2022/2/19.
//

#import "ViewController.h"
#import "Tool.h"
#import "EncodeUtil.h"
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

- (IBAction)encodeDidClicked:(UIButton *)sender {
    [self.encodeUtil convertPCMToAAC];
}

- (IBAction)decordDidClicked:(UIButton *)sender {
    [self.decodeUtil decodeAudio];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    [Tool showDeviceInfo];
}
@end

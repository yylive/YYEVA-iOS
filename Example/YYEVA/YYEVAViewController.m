//
//  YYEVAViewController.m
//  YYEVA
//
//  Created by guoyabin on 04/21/2022.
//  Copyright (c) 2022 guoyabin. All rights reserved.
//

#import "YYEVAViewController.h"
#import <YYEVA/YYEVA.h>
#import "YYEVAPlayer+HttpURL.h""
@interface YYEVAViewController () <IYYEVAPlayerDelegate>
@property (nonatomic, strong) YYEVAPlayer *player;
@property (nonatomic, strong) UIButton *pauseRenderBtn;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) NSString *showText;
@property (nonatomic, strong) UITextField *attrTextField;
@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *output;

@end

@implementation YYEVAViewController
 
  
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIView *toolBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 64, self.view.bounds.size.width, 140)];
    [self.view addSubview:toolBarView];
    
    UIButton *normalRenderBtn = [[UIButton alloc] initWithFrame:CGRectMake(10, 0, 100, 44)];
    [normalRenderBtn setTitle:@"普通视频" forState:UIControlStateNormal];
    [normalRenderBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    normalRenderBtn.backgroundColor  = [UIColor orangeColor];
    [normalRenderBtn addTarget:self action:@selector(onClickNormalRenderBtn) forControlEvents:UIControlEventTouchUpInside];
    [toolBarView addSubview:normalRenderBtn];
    
    UIButton *maskRenderBtn = [[UIButton alloc] initWithFrame:CGRectMake(120, 0, 120, 44)];
    [maskRenderBtn setTitle:@"动态元素视频" forState:UIControlStateNormal];
    [maskRenderBtn addTarget:self action:@selector(onClickMaskRenderBtn) forControlEvents:UIControlEventTouchUpInside];
    [maskRenderBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    maskRenderBtn.backgroundColor  = [UIColor yellowColor];
    [toolBarView addSubview:maskRenderBtn];
    
    UIButton *paustBtn = [[UIButton alloc] initWithFrame:CGRectMake(260, 0, 120, 22)];
    [paustBtn setTitle:@"暂停" forState:UIControlStateNormal];
    [paustBtn addTarget:self action:@selector(onClickPauseBtn) forControlEvents:UIControlEventTouchUpInside];
    [paustBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    paustBtn.backgroundColor  = [UIColor purpleColor];
    [toolBarView addSubview:paustBtn];
    
    UIButton *resumeBtn = [[UIButton alloc] initWithFrame:CGRectMake(260, 26, 120, 22)];
    [resumeBtn setTitle:@"继续" forState:UIControlStateNormal];
    [resumeBtn addTarget:self action:@selector(onClickResumeBtn) forControlEvents:UIControlEventTouchUpInside];
    [resumeBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    resumeBtn.backgroundColor  = [UIColor brownColor];
    [toolBarView addSubview:resumeBtn];
     
     
    
    UITextField *textField =  [[UITextField alloc] initWithFrame:CGRectMake(30, 54, 240, 30)];
    textField.placeholder = @"输入可替换的文案";
    textField.borderStyle = UITextBorderStyleBezel;
    textField.clearsOnBeginEditing = YES;
    [toolBarView addSubview:textField];
    self.textField = textField;
    
    {
        UITextField *textField =  [[UITextField alloc] initWithFrame:CGRectMake(30, 54 + 40, 240, 30)];
        textField.placeholder = @"输入富文本的文案";
        textField.borderStyle = UITextBorderStyleBezel;
        textField.clearsOnBeginEditing = YES;
        [toolBarView addSubview:textField];
        self.attrTextField = textField;
    }
}

- (void)onClickPauseBtn
{
    [self.player pause];
}
- (void)onClickResumeBtn
{
    [self.player resume];
}
 
  
 
- (void)onClickNormalRenderBtn
{
    [self.textField resignFirstResponder];
     
    NSString *file = [[NSBundle mainBundle] pathForResource:@"宠物504空闲_alpha_264_mid.mp4" ofType:nil];
    [self playWithFile:file];
    //Test HTTP
//    [self playWithHTTPURL:@"https://lxcode.bs2cdn.yy.com/92d5a19f-4288-41e6-835a-e092880c4af7.mp4"];
    
//    [self testReadSample];
}

- (void)playWithFile:(NSString *)file
{
    if (self.player) {
        [self.player stopAnimation];
        self.player = nil;
    }
    
    YYEVAPlayer *player = [[YYEVAPlayer alloc] init];
    player.disalbleMetalCache = YES;
    player.delegate = self;
    [self.view addSubview:player];
    player.frame = [self playViewFrame];
    [player play:file];
    self.player = player;
}

- (void)playWithHTTPURL:(NSString *)url
{
    if (self.player) {
        [self.player stopAnimation];
        self.player = nil;
    }
    
    YYEVAPlayer *player = [[YYEVAPlayer alloc] init];
    player.delegate = self;
    [self.view addSubview:player];
    player.frame = [self playViewFrame];
    [player playHttpURL:url];
    self.player = player;
}


- (void)onClickMaskRenderBtn
{
    [self.view endEditing:YES];

    NSString *file = [[NSBundle mainBundle] pathForResource:@"crush_avator.mp4" ofType:nil];
    NSString *str = self.textField.text;
    
    if (self.player) {
        [self.player stopAnimation];
        self.player = nil;
    }
    
    NSString *png1 = [[NSBundle mainBundle] pathForResource:@"avatar.png" ofType:nil];
    NSString *png2 = [[NSBundle mainBundle] pathForResource:@"ball_2.png" ofType:nil];
    NSString *png3 = [[NSBundle mainBundle] pathForResource:@"ball_3.png" ofType:nil];
     
    YYEVAPlayer *player = [[YYEVAPlayer alloc] init];
    player.disalbleMetalCache = YES;
    player.delegate = self;
    [self.view addSubview:player];
    player.frame = [self playViewFrame];
    self.player = player;
    
    //配置相关属性
    [player setImageUrl:png1 forKey:@"head2"];
    [player setText:str.length ? str :@"可替换文案" forKey:@"name"];
    if (self.attrTextField.text.length > 0) {
        NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
        NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:self.attrTextField.text.length > 0 ? self.attrTextField.text : @"富文本文案" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:32 weight:UIFontWeightBold], NSForegroundColorAttributeName: [UIColor greenColor], NSBackgroundColorAttributeName: [UIColor blueColor], NSParagraphStyleAttributeName: paragraphStyle}];
        
        NSTextAttachment *attach = [NSTextAttachment new];
        attach.bounds = CGRectMake(0, 0, 32, 32);
        attach.image = [UIImage imageNamed:@"ball_1.png"];
        NSAttributedString *attachString = [NSAttributedString attributedStringWithAttachment:attach];
        [attrText appendAttributedString:attachString];
        
        [player setAttrText:attrText forKey:@"keyname.png"];
    }

//    player.regionMode = YYEVAColorRegion_AlphaMP4_LeftGrayRightColor; //指定色彩区域
    //开始播
    [player play:file];
//    [player play:file repeatCount:5];
}

- (CGRect)playViewFrame
{
    return CGRectMake(0, 300, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height - 300);
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSString *)safeObjectArrs:(NSArray *)arr atIndex:(NSInteger)index
{
    if (index >= 0 && index < arr.count) {
        return [arr objectAtIndex:index];
    }
    
    return @"";
     
}
 
#pragma mark - YYEVAPlayerDelegate

- (void)evaPlayerDidCompleted:(YYEVAPlayer *)videoPlayer
{
    [videoPlayer stopAnimation];
    [videoPlayer removeFromSuperview];
    if (videoPlayer == self.player) {
        self.player = nil;
    }
}

- (void)evaPlayerDidStart:(YYEVAPlayer *)player
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)evaPlayer:(YYEVAPlayer *)player playFail:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)evaPlayerDidStart:(YYEVAPlayer *)player isRestart:(BOOL)isRestart
{
    NSLog(@"%s, isRestart: %@", __PRETTY_FUNCTION__, @(isRestart));
}

- (void)evaPlayer:(YYEVAPlayer *)player onPlayFrame:(NSInteger)frame frameCount:(NSInteger)frameCount
{
    NSLog(@"%s, frame: %@, frameCount: %@", __PRETTY_FUNCTION__, @(frame), @(frameCount));
}

 

- (void)testReadSample
{
    NSString *file = [[NSBundle mainBundle] pathForResource:@"new.mp4" ofType:nil];
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:file] options:nil];
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
    AVAssetTrack *assetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    NSDictionary *outputSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
        (id)kCVPixelBufferMetalCompatibilityKey: @(YES),
    };
    AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:assetTrack outputSettings:outputSettings];
    output.alwaysCopiesSampleData = NO;
    [reader addOutput:output];
    [reader startReading];
    self.reader = reader;
    self.output = output;
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:imageView];
    [NSTimer scheduledTimerWithTimeInterval:1.0/30.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self readVideoTracksIntoQueueIfNeed:imageView];
    }];
}

- (void)readVideoTracksIntoQueueIfNeed:(UIImageView *)imageView
{
    if (self.reader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef sampleBufferRef = [self.output copyNextSampleBuffer];
        
        if (sampleBufferRef) {
            UIImage *image = [self imageFromSampleBuffer:sampleBufferRef];
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
            sampleBufferRef = nil;
            
            imageView.image = image;
        }
    }
}

//转换图片
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // 1. 从 CMSampleBufferRef 获取 CVImageBufferRef
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 2. 从 CVImageBufferRef 创建 CIImage
    CIImage *ciImage = [CIImage imageWithCVImageBuffer:imageBuffer];
    
    // 3. 从 CIImage 创建 CGImage
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer))];
    
    // 4. 从 CGImage 创建 UIImage
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    // 5. 释放资源
    CGImageRelease(cgImage);
    
    return image;
}



@end

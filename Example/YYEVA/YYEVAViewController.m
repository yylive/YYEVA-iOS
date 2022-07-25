//
//  YYEVAViewController.m
//  YYEVA
//
//  Created by guoyabin on 04/21/2022.
//  Copyright (c) 2022 guoyabin. All rights reserved.
//

#import "YYEVAViewController.h"
#import <YYEVA/YYEVA.h>

@interface YYEVAViewController () <IYYEVAPlayerDelegate>
@property (nonatomic, strong) YYEVAPlayer *player;
@property (nonatomic, strong) UIButton *pauseRenderBtn;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) NSString *showText;
@end

@implementation YYEVAViewController
 
  
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIView *toolBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 64, self.view.bounds.size.width, 88)];
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
     
    
    UITextField *textField =  [[UITextField alloc] initWithFrame:CGRectMake(30, 54, 240, 30)];
    textField.placeholder = @"输入可替换的文案";
    textField.borderStyle = UITextBorderStyleBezel;
    textField.clearsOnBeginEditing = YES;
    [toolBarView addSubview:textField];
    self.textField = textField;
     
}
 
  
 
- (void)onClickNormalRenderBtn
{
    [self.textField resignFirstResponder];
     
    NSString *file = [[NSBundle mainBundle] pathForResource:@"alpha.mp4" ofType:nil];
     
    if (self.player) {
        [self.player stopAnimation];
        self.player = nil;
    }
    
    YYEVAPlayer *player = [[YYEVAPlayer alloc] init];
    player.delegate = self;
    player.backgroundColor = [UIColor clearColor];
    [self.view addSubview:player];
    player.frame = [self playViewFrame];
    [player play:file];
    
    self.player = player;
}

- (void)onClickMaskRenderBtn
{
    NSString *file = [[NSBundle mainBundle] pathForResource:@"effect.mp4" ofType:nil];
    NSString *str = self.textField.text;
    
    if (self.player) {
        [self.player stopAnimation];
        self.player = nil;
    }
    
    NSString *png1 = [[NSBundle mainBundle] pathForResource:@"ball_1.png" ofType:nil];
    NSString *png2 = [[NSBundle mainBundle] pathForResource:@"ball_2.png" ofType:nil];
    NSString *png3 = [[NSBundle mainBundle] pathForResource:@"ball_3.png" ofType:nil];
     
    YYEVAPlayer *player = [[YYEVAPlayer alloc] init];
    player.delegate = self;
    [self.view addSubview:player];
    player.frame = [self playViewFrame];
    self.player = player;
    
    //配置相关属性
    [player setImageUrl:png1 forKey:@"anchor_avatar1"];
    [player setImageUrl:png2 forKey:@"anchor_avatar2"];
    [player setImageUrl:png3 forKey:@"anchor_avatar3"];
    [player setText:str.length ? str :@"可替换文案" forKey:@"anchor_nick"];
    
    //开始播
    [player play:file];
}

- (CGRect)playViewFrame
{
    return CGRectMake(0, 150, 380, 422);
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
 
@end

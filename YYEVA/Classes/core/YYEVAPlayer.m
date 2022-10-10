//
//  YYEVAPlayer.m
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//

#import "YYEVAPlayer.h"
#import "IYYEVAVideoRenderProtol.h"
#import "YYEVAAssets.h"
#import "YYEVAVideoAlphaRender.h"
#import "YYEVAVideoEffectRender.h"

@import MetalKit;

@interface YYEVAPlayer()
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) YYEVAAssets *assets;
@property (nonatomic, strong) id<IYYEVAVideoRenderProtol> videoRender;
@property (nonatomic, copy)   NSString *fileUrl;
@property (nonatomic, strong) NSMutableDictionary *imgUrlKeys;
@property (nonatomic, strong) NSMutableDictionary *textKeys;
@property (nonatomic, copy)   NSString *bgImageUrl;
@property (nonatomic, assign) UIViewContentMode bgContentMode;
@property (nonatomic, assign) NSInteger repeatCount;
@end

@implementation YYEVAPlayer
 
- (instancetype)init
{
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];
        self.mode = YYEVAContentMode_ScaleAspectFit;
        self.repeatCount = 1;
    }
    return self;
}

- (void)dealloc
{ 
    [self stopAnimation];
}

#pragma  mark - public
 
- (void)setText:(NSString *)text forKey:(NSString *)key
{
    [self.textKeys setObject:text forKey:key];
}

- (void)setImageUrl:(NSString *)imgUrl forKey:(NSString *)key
{
    [self.imgUrlKeys setObject:imgUrl forKey:key];
}


//1.创建资源文件
//2.解析资源文件
//3.解析完成
//4.开始播放
- (void)play:(NSString *)url
{
    [self play:url repeatCount:1];
}

- (void)play:(NSString *)fileUrl repeatCount:(NSInteger)repeatCount
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self playWithFileUrl:fileUrl repeatCount:repeatCount];
    });
}



 
- (void)switchAssets:(YYEVAAssets *)assets
{
    if (self.assets) {
        [self stopAnimation];
        self.assets = nil;
    }
    _assets = assets;
    if (self.textKeys.count || self.imgUrlKeys.count) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        self.textKeys.count == 0 ?: [dict addEntriesFromDictionary:self.textKeys] ;
        self.imgUrlKeys.count == 0 ?: [dict addEntriesFromDictionary:self.imgUrlKeys] ;
        assets.businessEffects = dict;
    }
    BOOL loadResult = [assets loadVideo];
    if (loadResult == NO) {
        [self endPlay];
    }
}

- (void)playWithFileUrl:(NSString *)url repeatCount:(NSInteger)repeatCount
{
    self.repeatCount = repeatCount;
    YYEVAAssets *assets = [[YYEVAAssets alloc] initWithFilePath:url];
    [self switchAssets:assets];
    //包含描述信息 走的是maskRender
    [self setupMetal];
    if (self.assets.isEffectVideo) {
        self.videoRender = [[YYEVAVideoEffectRender alloc] initWithMetalView:self.mtkView];
        [(YYEVAVideoEffectRender *)self.videoRender setBgImageUrl:self.bgImageUrl contentMode:self.bgContentMode];
    } else {
        self.videoRender = [[YYEVAVideoAlphaRender alloc] initWithMetalView:self.mtkView];
    }
   self.videoRender.fillMode = self.mode;
   self.mtkView.delegate = self.videoRender;
   self.mtkView.frame = self.bounds;
   self.mtkView.backgroundColor = [UIColor clearColor];
   self.mtkView.preferredFramesPerSecond = assets.preferredFramesPerSecond ;

    __weak typeof(self) weakSelf = self;
       
    self.videoRender.completionPlayBlock = ^{
        weakSelf.repeatCount--;
        if (weakSelf.repeatCount > 0) {
//            [weakSelf playWithFileUrl:url repeatCount:weakSelf.repeatCount];
            [weakSelf.assets reload];
        } else {
            weakSelf.mtkView.paused = YES;
            [weakSelf endPlay];
        }
        
    };
   [self.videoRender playWithAssets:assets];
   [self.assets tryPlayAudio];
}
 

- (void)endPlay
{
    [self stopAnimation];
    [self.imgUrlKeys removeAllObjects];
    [self.textKeys removeAllObjects];
    if ([self.delegate respondsToSelector:@selector(evaPlayerDidCompleted:)]) {
        [self.delegate evaPlayerDidCompleted:self];
    }
}

- (void)setupMetal
{
    if (!_mtkView) {
        _mtkView = [[MTKView alloc] initWithFrame:self.bounds];
        [self addSubview:_mtkView];
        _mtkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _mtkView.device = MTLCreateSystemDefaultDevice();
        _mtkView.backgroundColor = [UIColor clearColor];
        self.mtkView.frame = self.bounds;
    }
}
 


- (void)stopAnimation
{
    [self pause];
    [self.mtkView removeFromSuperview];
    self.mtkView = nil;
    [self.assets clear];
    self.assets = nil;
    self.videoRender = nil;
}
 
- (void)pause
{
   self.mtkView.paused = YES;
}

#pragma mark - get/set
 
- (NSMutableDictionary *)imgUrlKeys
{
    if (!_imgUrlKeys) {
        _imgUrlKeys = [NSMutableDictionary dictionary];
    }
    return _imgUrlKeys;
}

- (NSMutableDictionary *)textKeys
{
    if (!_textKeys) {
        _textKeys = [NSMutableDictionary dictionary];
    }
    return _textKeys;
}
 
- (void)setBackgroundImage:(NSString *)imgUrl scaleMode:(UIViewContentMode)contentMode
{
    self.bgImageUrl = imgUrl;
    self.bgContentMode = contentMode;
}


@end

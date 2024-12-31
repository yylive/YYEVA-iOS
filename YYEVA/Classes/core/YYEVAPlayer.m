//
//  YYEVAPlayer.m
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//

#import "YYEVAPlayer.h"
#import "IYYEVAVideoRenderProtol.h"
#import "YYEVAVideoAlphaRender.h"
#import "YYEVAVideoEffectRender.h"

@interface NSTimer (WeakTimer)
+ (NSTimer *)scheduledWeakTimerWithTimeInterval:(NSTimeInterval)interval target:(id)aTarget selector:(SEL)aSelector userInfo:(id)userInfo repeats:(BOOL)repeats;
@end

@interface TimerWeakObject : NSObject
@property (nonatomic,weak) id target;
@property (nonatomic,assign) SEL selector;
@property (nonatomic,weak) NSTimer *timer;

- (void)fire:(NSTimer *)timer;
@end
@implementation TimerWeakObject
- (void)fire:(NSTimer *)timer {
    if (self.target) {
        if ([self.target respondsToSelector:self.selector]) {
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self.target performSelector:self.selector withObject:timer.userInfo];
        }
    }else {
        [self.timer invalidate];
    }
}

@end
@implementation NSTimer (WeakTimer)
+ (NSTimer *)scheduledWeakTimerWithTimeInterval:(NSTimeInterval)interval target:(id)aTarget selector:(SEL)aSelector userInfo:(id)userInfo repeats:(BOOL)repeats {
    TimerWeakObject *object = [[TimerWeakObject alloc]init];
    object.target = aTarget;
    object.selector = aSelector;
    object.timer = [NSTimer scheduledTimerWithTimeInterval:interval target:object selector:@selector(fire:) userInfo:userInfo repeats:repeats];
    
    return object.timer;
}
@end

@import MetalKit;

@interface YYEVAPlayer()<YYEVAAssetsDelegate>
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) id<IYYEVAVideoRenderProtol> videoRender;
@property (nonatomic, copy)   NSString *fileUrl;
@property (nonatomic, strong) NSMutableDictionary *imgUrlKeys;
@property (nonatomic, strong) NSMutableDictionary *textKeys;
@property (nonatomic, copy)   NSString *bgImageUrl;
@property (nonatomic, assign) UIViewContentMode bgContentMode;
@property (nonatomic, assign) NSInteger repeatCount;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isFirstPlay;
@end

@implementation YYEVAPlayer
 
- (instancetype)init
{
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];
        self.mode = YYEVAContentMode_ScaleAspectFit;
        self.regionMode = YYEVAColorRegion_NoSpecify;
        self.repeatCount = 1;
        _volume = 1;
        _isFirstPlay = YES;
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
    if (text.length <= 0) return;
    [self.textKeys setObject:@{@"content":text} forKey:key];
}

- (void)setAttrText:(NSAttributedString *)attrText forKey:(NSString *)key
{
    if (attrText == nil) return;
    [self.textKeys setObject:@{@"attrText": [attrText copy]} forKey:key];
}

- (void)setText:(NSString *)text forKey:(NSString *)key textAlign:(NSTextAlignment)textAlign
{
    if (text.length <= 0) return;
    [self.textKeys setObject:@{@"content":text,@"align":@(textAlign)} forKey:key];
}

- (void)setImageUrl:(NSString *)imgUrl forKey:(NSString *)key
{
    if (imgUrl.length > 0 && key.length > 0) {
        [self.imgUrlKeys setObject:imgUrl forKey:key];
    }
    
}

- (void)setImage:(UIImage *)image forKey:(NSString *)key
{
    if (image  && key.length > 0) {
        [self.imgUrlKeys setObject:image forKey:key];
    }
    
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
    if ([NSThread isMainThread]) {
        [self playWithFileUrl:fileUrl repeatCount:repeatCount];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playWithFileUrl:fileUrl repeatCount:repeatCount];
        });
    }
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
    _assets.volume = self.volume;
    BOOL loadResult = [assets loadVideo];
    if (loadResult == NO) {
        [self endPlay:YES];
    }
}

- (void)prepareToPlay:(NSString *)fileUrl repeatCount:(NSInteger)repeatCount
{
    self.repeatCount = repeatCount;
    if (repeatCount == 0) {
        self.loop = YES;
    }
    YYEVAAssets *assets = [[YYEVAAssets alloc] initWithFilePath:fileUrl];
    assets.region = self.regionMode;
    assets.delegate = self;
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
   self.videoRender.disalbleMetalCache = self.disalbleMetalCache;
   self.mtkView.delegate = self.videoRender;
   self.mtkView.frame = self.bounds;
   self.mtkView.backgroundColor = [UIColor clearColor];
   self.mtkView.preferredFramesPerSecond = assets.preferredFramesPerSecond ;
   self.mtkView.paused = YES;
   self.mtkView.enableSetNeedsDisplay = false;
   
    __weak typeof(self) weakSelf = self;
       
    self.videoRender.completionPlayBlock = ^{
        weakSelf.isFirstPlay = NO;
        if (weakSelf.loop) {
            [weakSelf.assets reload];
            [weakSelf timerStart];
        } else {
            [weakSelf timerEnd];
            weakSelf.repeatCount--;
            if (weakSelf.repeatCount > 0) {
                [weakSelf.assets reload];
                [weakSelf timerStart];
            } else {
                [weakSelf endPlay:NO];
            }
        }
    };
   [self.videoRender playWithAssets:assets];
}

- (void)playWithFileUrl:(NSString *)url repeatCount:(NSInteger)repeatCount
{
    [self prepareToPlay:url repeatCount:repeatCount];
    [self play];
}

- (void)play
{
    [self.assets tryPlayAudio];
    [self timerStart];
}
 
- (void)timerDraw
{
    [self.mtkView draw];
}

- (void)timerEnd
{
    if(_timer) {
        [_timer invalidate];
        _timer = nil;
    }
}

- (void)timerStart
{
    [self timerEnd];
    NSTimeInterval per =  1.0 / self.assets.preferredFramesPerSecond;
   
    self.timer = [NSTimer scheduledWeakTimerWithTimeInterval:per target:self selector:@selector(timerDraw) userInfo:nil repeats:YES];
    NSRunLoopMode mode = NSRunLoopCommonModes;
    if (![self.assets existAudio] && self.runlLoopMode != nil) {
        mode = self.runlLoopMode;
    }
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:mode];
}

- (void)endPlay:(BOOL)force
{
    if (!self.setLastFrame || force) {
        [self stopAnimation];
        [self.imgUrlKeys removeAllObjects];
        [self.textKeys removeAllObjects];
        
        if ([self.delegate respondsToSelector:@selector(evaPlayerDidCompleted:)]) {
            [self.delegate evaPlayerDidCompleted:self];
        }
    } else {
        [self pause];
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
    [self.assets clear];
    self.assets = nil;
    self.videoRender = nil;
    self.mtkView = nil;
}
 
- (void)pause
{
    //暂停视频流的渲染
    [self timerEnd];
    //暂停音频流
    [self.assets pauseAudio];
}

- (void)resume
{
    [self timerStart];
    
    [self.assets resumeAudio];
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

- (void)setRegionMode:(YYEVAColorRegion)regionMode
{
    if (_regionMode == regionMode) {
        return;
    }
    
    _regionMode = regionMode;
    self.assets.region = regionMode;
}

- (void)setVolume:(float)volume
{
    _volume = volume;
    self.assets.volume = volume;
}

#pragma mark - YYEVAAssetsDelegate

- (void)assetsDidStart:(YYEVAAssets *)asset
{
    NSLog(@"url:%@ did start",asset.filePath);
    
    if ([self.delegate respondsToSelector:@selector(evaPlayerDidStart:)]){
        [self.delegate evaPlayerDidStart:self];
    }
    
    if ([self.delegate respondsToSelector:@selector(evaPlayerDidStart:isRestart:)]) {
        [self.delegate evaPlayerDidStart:self isRestart:!self.isFirstPlay];
    }
}
- (void)assetsDidLoadFaild:(YYEVAAssets *)asset failure:(NSError *)error
{
    NSLog(@"url:%@ did load failed",asset.filePath);
    
    if ([self.delegate respondsToSelector:@selector(evaPlayer:playFail:)]){
        [self.delegate evaPlayer:self playFail:error];
    }
}

- (void)assets:(YYEVAAssets *)asset onPlayFrame:(NSInteger)frame frameCount:(NSInteger)frameCount
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(evaPlayer:onPlayFrame:frameCount:)]) {
        [self.delegate evaPlayer:self onPlayFrame:frame frameCount:frameCount];
    }
}

@end

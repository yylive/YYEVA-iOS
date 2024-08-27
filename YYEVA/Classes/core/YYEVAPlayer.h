//
//  YYEVAPlayer.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//  播放器入口

#import <Foundation/Foundation.h>
#import "YYEVACommon.h"
#import <UIKit/UIKit.h>
#import "YYEVAAssets.h"

NS_ASSUME_NONNULL_BEGIN
 
@class YYEVAPlayer;
  
//播放器的回调通知
@protocol IYYEVAPlayerDelegate <NSObject>

@optional

// 每次开始播放都会回调，不区分首次非首次
- (void)evaPlayerDidStart:(YYEVAPlayer *)player;

// 每次开始播放都会回调，isRestart为NO代表首次播放，YES代表非首次播放
- (void)evaPlayerDidStart:(YYEVAPlayer *)player isRestart:(BOOL)isRestart;

// 播放结束
- (void)evaPlayerDidCompleted:(YYEVAPlayer *)player;

// 播放失败
- (void)evaPlayer:(YYEVAPlayer *)player playFail:(NSError *)error;

// frame：当前播放的帧数，frameCount：总帧数。尽量不要监听每一帧做耗时的操作，可能卡顿。
- (void)evaPlayer:(YYEVAPlayer *)player onPlayFrame:(NSInteger)frame frameCount:(NSInteger)frameCount;

@end

@interface YYEVAPlayer : UIView

@property (nonatomic, strong, nullable) YYEVAAssets *assets;

@property (nonatomic, weak) id<IYYEVAPlayerDelegate> delegate;
/// 视频拉伸模式
@property (nonatomic, assign) YYEVAFillMode mode;
/// 颜色区域
@property (nonatomic, assign) YYEVAColorRegion regionMode;

/// 当前渲染的runloop模式，仅无音频的视频可设置
/// 默认是NSRunLoopCommonModes
/// 无音频的视频可设置NSDefaultRunLoopMode，滑动时不渲染，优化性能。
@property (nullable, copy) NSRunLoopMode runlLoopMode;

@property (nonatomic, assign) float volume;

// true表示一直循环播放
@property (nonatomic, assign) BOOL loop;

// true 表示停在最后一帧
@property (nonatomic, assign) BOOL setLastFrame;

// 禁用CVMetalTextureCache，内存下降明显，CPU略微上涨，可根据业务灵活使用。默认NO
@property (nonatomic, assign) BOOL disalbleMetalCache;

//播放
- (void)play:(NSString *)fileUrl;
// 0表示一直循环播放
- (void)play:(NSString *)fileUrl repeatCount:(NSInteger)repeatCount;

// 提前准备播放器
- (void)prepareToPlay:(NSString *)fileUrl repeatCount:(NSInteger)repeatCount;
- (void)play;

- (void)pause;
- (void)resume;
- (void)stopAnimation;

//设置相关动态属性
- (void)setText:(NSString *)text forKey:(NSString *)key;
- (void)setText:(NSString *)text forKey:(NSString *)key textAlign:(NSTextAlignment)textAlign;
- (void)setAttrText:(NSAttributedString *)attrText forKey:(NSString *)key;
- (void)setImageUrl:(NSString *)imgUrl forKey:(NSString *)key;
- (void)setImage:(UIImage *)image forKey:(NSString *)key;

//设置背景层
- (void)setBackgroundImage:(NSString *)imgUrl
                 scaleMode:(UIViewContentMode)contentMode;

@end

NS_ASSUME_NONNULL_END

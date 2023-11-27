//
//  YYEVAPlayer.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//  播放器入口

#import <Foundation/Foundation.h>
#import "YYEVACommon.h"
#import <UIKit/UIKit.h>


NS_ASSUME_NONNULL_BEGIN
 
@class YYEVAPlayer;
  
//播放器的回调通知
@protocol IYYEVAPlayerDelegate <NSObject>
@optional
- (void)evaPlayerDidStart:(YYEVAPlayer *)player;
- (void)evaPlayerDidCompleted:(YYEVAPlayer *)player;
- (void)evaPlayer:(YYEVAPlayer *)player playFail:(NSError *)error;
@end

@interface YYEVAPlayer : UIView

@property (nonatomic, assign) id<IYYEVAPlayerDelegate> delegate;
/// 视频拉伸模式
@property (nonatomic, assign) YYEVAFillMode mode;
/// 颜色区域
@property (nonatomic, assign) YYEVAColorRegion regionMode;

/// 当前渲染的runloop模式，仅无音频的视频可设置
/// 默认是NSRunLoopCommonModes
/// 无音频的视频可设置NSDefaultRunLoopMode，滑动时不渲染，优化性能。
@property (nullable, copy) NSRunLoopMode runlLoopMode;

//播放
- (void)play:(NSString *)fileUrl;
// 0表示一直循环播放
- (void)play:(NSString *)fileUrl repeatCount:(NSInteger)repeatCount;
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

// 设置音量
- (void)setVolumn:(double)volumn;


@end

NS_ASSUME_NONNULL_END

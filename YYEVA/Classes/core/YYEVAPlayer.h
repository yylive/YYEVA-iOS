//
//  YYEVAPlayer.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//  播放器入口

#import <Foundation/Foundation.h>
#import "YYEVACommon.h"

NS_ASSUME_NONNULL_BEGIN
 
@class YYEVAPlayer;
  
//播放器的回调通知
@protocol IYYEVAPlayerDelegate <NSObject>
@optional 
- (void)evaPlayerDidCompleted:(YYEVAPlayer *)player;
@end

@interface YYEVAPlayer : UIView

@property (nonatomic, assign) id<IYYEVAPlayerDelegate> delegate;
//视频拉伸模式
@property (nonatomic, assign) YYEVAFillMode mode;

//播放
- (void)play:(NSString *)fileUrl;
// 0表示一直循环播放
- (void)play:(NSString *)fileUrl repeatCount:(NSInteger)repeatCount;
- (void)pause;
- (void)stopAnimation;

//设置相关动态属性
- (void)setText:(NSString *)text forKey:(NSString *)key;
- (void)setImageUrl:(NSString *)imgUrl forKey:(NSString *)key;

//设置背景层
- (void)setBackgroundImage:(NSString *)imgUrl
                 scaleMode:(UIViewContentMode)contentMode;

@end

NS_ASSUME_NONNULL_END

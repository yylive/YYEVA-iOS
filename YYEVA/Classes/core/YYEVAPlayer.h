//
//  YYEVAPlayer.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//

#import <Foundation/Foundation.h>
#import "YYEVACommon.h"

NS_ASSUME_NONNULL_BEGIN



@class YYEVAPlayer;
  
@protocol IYYEVAPlayerDelegate <NSObject>

@optional 
- (void)evaPlayerDidCompleted:(YYEVAPlayer *)player; 
 
@end

@interface YYEVAPlayer : UIView
 
@property (nonatomic, assign) id<IYYEVAPlayerDelegate> delegate;

@property (nonatomic, assign) YYEVAFillMode mode;

//播放
- (void)play:(NSString *)fileUrl;
  
- (void)pause;
- (void)stopAnimation;

//设置相关动态属性
- (void)setText:(NSString *)text forKey:(NSString *)key;
- (void)setImageUrl:(NSString *)imgUrl forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

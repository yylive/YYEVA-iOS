//
//  YYEVACommon.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
 

#define CheckReturnNil(x) if (!x) { \
    return nil; \
}
 
typedef NS_ENUM(NSInteger,YYEVAEffectSourceType) {
    YYEVAEffectSourceTypeUnkown = -1,
    YYEVAEffectSourceTypeText = 0,
    YYEVAEffectSourceTypeImage = 1
};

typedef NS_ENUM(NSInteger,YYEVAEffectSourceImageFillMode) {
    YYEVAEffectSourceImageFillModeScaleFill = 0,
    YYEVAEffectSourceImageFillModeAspectFit = 1,
    YYEVAEffectSourceImageFillModeAspectFill = 2,
};

/**
 播放器状态
 */
typedef NS_ENUM(NSUInteger, YYEVAPlayerStatus) {
    YYEVAPlayerStatus_Unknown = 0, // 未知，播放器未加载asset
    YYEVAPlayerStatus_Play = 1,
    YYEVAPlayerStatus_Stall = 2, // 卡顿
    YYEVAPlayerStatus_Pause = 3,
    YYEVAPlayerStatus_End = 4, // 表示已播到末尾
};

//MP4资源播放的拉伸模式
typedef NS_ENUM(NSInteger,YYEVAFillMode){
    YYEVAContentMode_ScaleToFill = 0,
    YYEVAContentMode_ScaleAspectFit = 1,
    YYEVAContentMode_ScaleAspectFill = 2,
};

NS_ASSUME_NONNULL_END

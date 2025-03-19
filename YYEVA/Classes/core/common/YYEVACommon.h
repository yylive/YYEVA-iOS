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
typedef NS_ENUM(NSInteger, YYEVAPlayerStatus) {
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


//MP4资源播放失败原因
typedef NS_ENUM(NSInteger,YYEVAPlayerErrorCode){
     FileNotExits = 1,//文件不存在
     LoadAssetsFail = 2, //资源解码失败
};


//MP4色彩区域
typedef NS_ENUM(NSInteger,YYEVAColorRegion) {
    YYEVAColorRegion_NoSpecify = 999,              ///< 默认没指定模式，将会自动检测
    YYEVAColorRegion_Invaile = 0,                 ///< 检测失败
    YYEVAColorRegion_NormalMP4,                   ///< 普通MP4，没透明区域
    YYEVAColorRegion_AlphaMP4_LeftColorRightGray, ///< 左彩色右透明
    YYEVAColorRegion_AlphaMP4_LeftGrayRightColor, ///< 左透明右彩色
    YYEVAColorRegion_AlphaMP4_TopColorBottomGray, ///< 上彩色下透明
    YYEVAColorRegion_AlphaMP4_TopGrayBottomColor,  ///< 上透明下彩色
    YYEVAColorRegion_AlphaMP4_alphaHalfRightTop      ///< alpha区域是rgb区域的一半，在右上角
};

NS_ASSUME_NONNULL_END

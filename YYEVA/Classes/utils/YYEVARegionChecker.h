//
//  YYEVARegionChecker.h
//  YYEVA
//
//  Created by wicky on 2023/4/20.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "YYEVACommon.h"

NS_ASSUME_NONNULL_BEGIN

@interface YYEVARegionChecker : NSObject

/// 传入一个文件，智能识别里面前3帧来判断色彩区域，假如某帧已判断成功，就退出。
/// - Parameter url: 文件url
- (YYEVAColorRegion)checkFile:(NSString *)url;


/// 传入一个文件，智能识别里面前maxFrame帧来判断色彩区域，假如某帧已判断成功，就退出。
/// - Parameters:
///   - url: 文件url
///   - maxFrame: 指定需要检测的前几帧。
- (YYEVAColorRegion)checkFile:(NSString *)url CheckMaxFrame:(NSInteger) maxFrame;


/// 传入一个视频帧采样，智能识别里面的色彩区域，假如检测失败，不会自动检测下一帧，这个留给开发者自己调用。
/// - Parameter sampleBuffer: 视频帧采样
- (YYEVAColorRegion)checkSampleRef:(CMSampleBufferRef)sampleBuffer;
@end

NS_ASSUME_NONNULL_END

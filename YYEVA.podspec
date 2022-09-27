#
# Be sure to run `pod lib lint YYEVA.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'YYEVA'
  s.version          = '1.0.9'
  s.summary      = "YYEVA 是一个能播放混合MP4的播放器"
  s.description  = <<-DESC
                   YYEVA 是一种在支持的静态MP4，动态插入元素的播放器解决方案，由 YY 团队主导开发；
                   YYEVA 让动画开发分工明确，大大减少动画交互的沟通成本，提升开发效率；
                   YYEVA 可以在 iOS / Android / Web  实现高性能的动画播放。
                   DESC

  s.homepage         = 'https://github.com/yylive/YYEVA'

  s.license          = { :type => 'Apache Version 2.0', :file => 'LICENSE' }
  s.author           = { 'guoyabin' => 'guoyabin2@yy.com' }
  s.source           = { :git => 'https://github.com/yylive/YYEVA-iOS.git', :tag => s.version.to_s }


  s.ios.deployment_target = '9.0'

  s.source_files = 'YYEVA/Classes/**/*'
   
  
  s.resource_bundles = {
     'YYEVABundle' => ['YYEVA/**/*.metal']
   } 
end

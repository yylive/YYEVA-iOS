# YY-EVA <sup>iOS</sup>  

简体中文 | [English](./README_en.md)

> 轻量级 高性能 跨平台 MP4 礼物播放器

## 支持本项目

请支持我们的项目，点击[⭐⭐⭐](https://github.com/yylive/YYEVA), 让更多的人看到该项目


## 案例演示

<img src="./resource/out_3.gif" width = "399" height = "428" alt="图片名称" align=center /> 


## 介绍
+ YYEVAPlayer 是一个轻量的动画渲染库。通过[这里](https://github.com/yylive/YYEVA/blob/main/YYEVA%E8%AE%BE%E8%AE%A1%E8%A7%84%E8%8C%83.md)导出动画文件
+ 通过[这里](https://github.com/yylive/YYEVA/tree/main/AEP/demo_aep)可以获取设计的测试资源文件   
+ YYEVA-iOS 使用原生 Metal 库渲染视频，为你提供高性能、低开销的动画体验。

## 平台支持
+ 支持 [Android](https://github.com/yylive/YYEVA-Android)、[IOS](https://github.com/yylive/YYEVA-iOS)、[Web](https://github.com/yylive/YYEVA-Web)   点击了解详细接入   
+ 资源制作的AE插件使用规范 [详情](https://github.com/yylive/YYEVA/tree/main/AEP)
+ 数据结构定义 [详情](https://github.com/yylive/YYEVA/blob/main/%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84.md)
+ 项目相关文章、设计规范等 [详情](https://github.com/yylive/YYEVA)

## 用法

### 使用Cocoapods安装依赖
+ 使用 CocoaPods 安装依赖
+ 添加依赖 'YYEVA' 到 Podfile 文件中:

```js
target 'MyApp' do 
  pod 'YYEVA' ,'1.0.1' 
end
```
### 使用SPM安装依赖
```
dependencies: [
    .package(url: "https://github.com/yylive/YYEVA-iOS.git", .upToNextMajor(from: "1.1.19"))
]
```

### 放置混合 mp4 文件 在bundle中

### 代码

创建一个`YYEVAPlayer`实例

```c++ 
YYEVAPlayer *player = [[YYEVAPlayer alloc] init];
[self.view addSubview:player]; 

//config dynmaic elements 
[player setImageUrl:localPath forKey:@"image_key1"];   
[player setImageUrl:localPath forKey:@"image_key2"];
[player setImageUrl:localPath forKey:@"image_key3"];
[player setText:str.text forKey:@"text_key1"];
 
[player play:file];
     
```

其中以下接口是给MP4动态插入,业务文字或图片的接口
+ setImageUrl:forKey    
+ setText:forKey 
 
## QQ交流群
![qqgroup](https://github.com/yylive/YYEVA/blob/main/img/qqgroup.png)

## 鸣谢 
+ 感谢 vap 优秀的混合渲染方案、项目Render混合部分重用了 vap的方案
 

## Dev Team
<table>
  <tbody>
    <tr>
      <td align="center" valign="top">
        <img style="border-radius:8px" width="80" height="80" src="https://avatars.githubusercontent.com/u/14030762?v=4&s=80">
        <br>
        <a href="https://github.com/guoyabiniOS">GuoyabiniOS</a>
      </td>
      <td align="center" valign="top">
        <img style="border-radius:8px" width="80" height="80" src="https://avatars.githubusercontent.com/u/44636610?v=4&s=80">
        <br>
        <a href="https://github.com/ganpenglong">Ganpenglong</a>
      </td>
    <td align="center" valign="top">
        <img style="border-radius:8px" width="80" height="80" src="https://avatars.githubusercontent.com/u/12680946?v=4&s=80">
        <br>
        <a href="https://github.com/WickyLeung">WickyLeung</a>
      </td> 
          <td align="center" valign="top">
        <img style="border-radius:8px" width="80" height="80" src="https://avatars.githubusercontent.com/u/10579296?s=96&v=4">
        <br>
        <a href="https://github.com/ynot16">ChenChengming</a>
      </td> 
     </tr>
  </tbody>
</table>

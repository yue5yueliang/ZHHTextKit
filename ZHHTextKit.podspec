Pod::Spec.new do |s|
  s.name             = 'ZHHTextKit'
  s.version          = '1.0.3'
  s.summary          = '纯 Swift 富文本组件，供 Feed、评论、私信等场景复用。'

  s.description      = <<-DESC
ZHHTextKit 提供与业务解耦的富文本解析、展示和输入：话题、提及、链接、电话、
按行截断与「全文 / 收起」、布局缓存与后台预计算、@ / # 发布 document（text + entities）、
自定义表情短码，以及正文胶囊标签。颜色和字体通过 ZHHTextStyle 注入。
                       DESC

  s.homepage         = 'https://github.com/yue5yueliang/ZHHTextKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '桃色三岁' => '136769890@qq.com' }
  s.source           = { :git => 'https://github.com/yue5yueliang/ZHHTextKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_versions = ['5.5']
  s.frameworks = 'UIKit', 'CoreText'

  # 隐私清单：不采集、不追踪、无 Required Reason API；resource_bundles 避免覆盖宿主 App 清单
  s.resource_bundles = {
    'ZHHTextKit' => ['ZHHTextKit/PrivacyInfo.xcprivacy']
  }

  # 默认 Source subspec：Development Pods 里单独一组源码树
  s.default_subspec = 'Source'

  s.subspec 'Source' do |ss|
    ss.source_files = 'ZHHTextKit/Classes/**/*'
  end
end

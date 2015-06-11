Pod::Spec.new do |s|
  s.name           = "TwUI"
  s.version        = "0.4.0"
  s.summary        = "A UI framework for Mac based on Core Animation."
  s.description    = "TwUI is a hardware accelerated UI framework for Mac, inspired by UIKit. It enables:\n"\
                     "- GPU accelerated rendering backed by CoreAnimation.\n"\
                     "- Simple model/view/controller development familiar to iOS developers."
  s.homepage       = "https://github.com/naituw/twui"
  s.author         = { "Twitter, Inc." => "opensource@twitter.com",
                       "GitHub, Inc." => "support@github.com" }
  s.license        = { :type => 'Apache License, Version 2.0' }
  s.source         = { :git => "https://github.com/Naituw/twui.git", :tag => s.version.to_s }

  s.platform       = :osx, '10.8'
  s.requires_arc   = true
  s.frameworks     = 'ApplicationServices', 'QuartzCore', 'Cocoa'

  s.source_files = 'lib/**/*.{h,m}'
  s.exclude_files = '**/*{TUIAccessibilityElement}*'
  s.prefix_header_file = "lib/UIKit/TUIKit.h"

  s.resources = 'Resources/*.{png}'

end

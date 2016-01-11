//
//  TUIViewControllerPreviewingContext.h
//  TwUI
//
//  Created by wutian on 16/1/10.
//
//

#import <Foundation/Foundation.h>

@interface TUIViewControllerPreviewingContext : NSObject

@property (nonatomic, weak) TUIView * sourceSubview;
@property (nonatomic, strong) NSBezierPath * sourcePath;
@property (nonatomic, assign) CGRect sourceRect;

@property (nonatomic, assign) CGSize preferredContentSize;

@property (nonatomic, weak, readonly) TUIView * sourceView;

@end

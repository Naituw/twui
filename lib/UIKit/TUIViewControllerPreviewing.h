//
//  TUIViewControllerPreviewing.h
//  TwUI
//
//  Created by wutian on 16/1/10.
//
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "TUIViewControllerPreviewingContext.h"
#import "TUIViewController.h"

@protocol TUIViewControllerPreviewing <NSObject>

@required
- (TUIViewController *)previewingContext:(TUIViewControllerPreviewingContext *)context viewControllerForLocation:(CGPoint)location;

@end

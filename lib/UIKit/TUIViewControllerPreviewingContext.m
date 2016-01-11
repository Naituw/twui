//
//  TUIViewControllerPreviewingContext.m
//  TwUI
//
//  Created by wutian on 16/1/10.
//
//

#import "TUIViewControllerPreviewingContext.h"
#import "TUIViewControllerPreviewingContext_Private.h"

@interface TUIViewControllerPreviewingContext ()

@property (nonatomic, weak) TUIView * sourceView;

@end

@implementation TUIViewControllerPreviewingContext

- (instancetype)init
{
    if (self = [super init]) {
        self.sourceRect = CGRectNull;
        self.sourcePath = nil;
    }
    return self;
}

- (instancetype)initWithSourceView:(TUIView *)sourceView
{
    if (self = [self init]) {
        self.sourceView = sourceView;
    }
    return self;
}

@end

//
//  TUITextLayoutLine_Private.h
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import "TUITextLayoutLine.h"
#import <CoreText/CoreText.h>

@interface TUITextLayoutLine ()

@property (nonatomic, assign) CTLineRef lineRef;

- (void)_offsetBaselineOriginWithDelta:(CGPoint)delta;

@end

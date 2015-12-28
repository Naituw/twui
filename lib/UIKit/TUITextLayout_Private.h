//
//  TUITextLayout_Private.h
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import "TUITextLayout.h"
#import "TUITextLayoutFrame.h"

@interface TUITextLayout ()

@property (nonatomic, strong, readonly) TUITextLayoutFrame * layoutFrame;

- (TUITextLayoutFrame *)createLayoutFrame;

@end

@interface TUITextLayout (Coordinates)

- (CGPoint)convertPointFromCoreText:(CGPoint)point;
- (CGPoint)convertPointToCoreText:(CGPoint)point;

- (CGRect)convertRectFromCoreText:(CGRect)rect;
- (CGRect)convertRectToCoreText:(CGRect)rect;

@end

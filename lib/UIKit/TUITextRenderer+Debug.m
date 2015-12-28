//
//  TUITextRenderer+Debug.m
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import "TUITextRenderer+Debug.h"
#import "TUITextLayoutFrame.h"
#import "TUITextLayoutLine.h"

@implementation TUITextRenderer (Debug)

- (void)debugModeDrawLineFramesWithLayoutFrame:(TUITextLayoutFrame *)layoutFrame context:(CGContextRef)ctx offset:(CGPoint)offset
{
    CGContextSaveGState(ctx);
    
    CGContextSetAlpha(ctx, 0.1);
    CGContextSetFillColorWithColor(ctx, [TUIColor greenColor].CGColor);
    CGContextFillRect(ctx, [self convertRectFromLayout:(CGRect){CGPointZero, self.textLayout.size}]);
    
    NSArray * lines = layoutFrame.lineFragments;
    
    CGFloat lineWidth = 1 / TUICurrentContextScaleFactor();
    
    [lines enumerateObjectsUsingBlock:^(TUITextLayoutLine * line, NSUInteger idx, BOOL *stop) {
        CGRect rect = line.fragmentRect;
        rect = [self convertRectFromLayout:rect];
        rect.origin.x += offset.x;
        rect.origin.y += offset.y;
        
        CGContextSaveGState(ctx);
        
        CGContextSetAlpha(ctx, 0.3);
        CGContextSetFillColorWithColor(ctx, [TUIColor blueColor].CGColor);
        CGContextFillRect(ctx, rect);
        
        CGRect baselineRect = CGRectMake(0, 0, rect.size.width, lineWidth);
        baselineRect.origin = [self convertPointFromLayout:line.baselineOrigin];
        
        CGContextSetAlpha(ctx, 0.6);
        CGContextSetFillColorWithColor(ctx, [TUIColor redColor].CGColor);
        CGContextFillRect(ctx, baselineRect);
        
        CGContextRestoreGState(ctx);
    }];
    
    CGContextRestoreGState(ctx);
}

@end

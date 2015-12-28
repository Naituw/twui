//
//  TUITextRenderer+Debug.h
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import "TUITextRenderer.h"
#import "TUITextLayoutFrame.h"

@interface TUITextRenderer (Debug)

- (void)debugModeDrawLineFramesWithLayoutFrame:(TUITextLayoutFrame *)layoutFrame context:(CGContextRef)ctx offset:(CGPoint)offset;

@end

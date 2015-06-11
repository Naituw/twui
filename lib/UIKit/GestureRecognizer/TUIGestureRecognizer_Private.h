//
//  TUIGestureRecognizer_Private.h
//  TwUI
//
//  Created by 吴天 on 12/7/14.
//
//

#import "TUIGestureRecognizer.h"

@class TUIView;

@interface TUIGestureRecognizer ()

- (void)_setView:(TUIView *)v;
- (void)_recognizeEvent:(NSEvent *)event;

@end

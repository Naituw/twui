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
{
    struct {
        unsigned int shouldBegin:1;
    } _delegateHas;
}

- (void)_setView:(TUIView *)v;
- (void)_recognizeEvent:(NSEvent *)event;

@end

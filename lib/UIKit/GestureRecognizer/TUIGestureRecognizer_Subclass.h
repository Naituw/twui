//
//  TUIGestureRecognizer_Subclass.h
//  TwUI
//
//  Created by 吴天 on 12/7/14.
//
//

#import "TUIGestureRecognizer.h"

@interface TUIGestureRecognizer ()

@property (nonatomic, readwrite) TUIGestureRecognizerState state;

- (void)reset;

- (void)mouseDown:(NSEvent *)theEvent;
- (void)rightMouseDown:(NSEvent *)theEvent;
- (void)mouseUp:(NSEvent *)theEvent;
- (void)rightMouseUp:(NSEvent *)theEvent;
- (void)mouseDragged:(NSEvent *)theEvent;
- (void)rightMouseDragged:(NSEvent *)theEvent;

- (void)scrollWheel:(NSEvent *)theEvent;

- (void)magnifyWithEvent:(NSEvent *)event;
- (void)rotateWithEvent:(NSEvent *)event;
- (void)swipeWithEvent:(NSEvent *)event;
- (void)beginGestureWithEvent:(NSEvent *)event;
- (void)endGestureWithEvent:(NSEvent *)event;

@end

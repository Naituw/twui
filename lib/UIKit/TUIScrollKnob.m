/*
 Copyright 2011 Twitter, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this work except in compliance with the License.
 You may obtain a copy of the License in the LICENSE file, or at:
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "TUIScrollKnob.h"
#import "TUICGAdditions.h"
#import "TUIScrollView.h"

static NSTimeInterval const TUIScrollIndicatorDisplayPeriod = 0.75f;

typedef NS_ENUM(NSInteger, TUIScrollKnobMode) {
    TUIScrollKnobModeCompact = 0,
    TUIScrollKnobModeFullWidth,
    TUIScrollKnobModeHidden,
};

@interface TUIScrollKnobBackgroundView : TUIView

@end

@interface TUIScrollKnob ()
{
    TUIScrollKnobMode _knobMode;
    
    struct {
        unsigned int active:1;
        unsigned int trackingInsideKnob:1;
        unsigned int scrollIndicatorStyle:2;
        unsigned int flashing:1;
    } _scrollKnobFlags;
}

@property (nonatomic, strong) TUIScrollKnobBackgroundView * backgroundView;
@property (nonatomic, strong) id scrollerStyleNotificationObserver;
@property (nonatomic, assign) NSScrollerStyle systemPreferedScrollerStyle;
@property (nonatomic, assign, readonly) BOOL hovering;

- (void)_endFlashing;

@end

@implementation TUIScrollKnob

@synthesize scrollView;
@synthesize knob;

- (id)initWithFrame:(CGRect)frame
{
    if((self = [super initWithFrame:frame]))
    {
        [self addSubview:self.backgroundView];
        
        _systemPreferedScrollerStyle = [NSScroller preferredScrollerStyle];
        
        knob = [[TUIView alloc] initWithFrame:CGRectZero];
        knob.userInteractionEnabled = NO;
        knob.backgroundColor = [TUIColor blackColor];
        [self addSubview:knob];
        
        _knobMode = -1;
        [self _updateKnobMode];
        
        __weak id weakSelf = self;
        
        self.scrollerStyleNotificationObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSPreferredScrollerStyleDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
            TUIScrollKnob * self = weakSelf;
            if (self == nil) return;
            
            self.systemPreferedScrollerStyle = [NSScroller preferredScrollerStyle];
        }];
    }
    return self;
}

- (void)setSystemPreferedScrollerStyle:(NSScrollerStyle)systemPreferedScrollerStyle
{
    if (_systemPreferedScrollerStyle != systemPreferedScrollerStyle) {
        _systemPreferedScrollerStyle = systemPreferedScrollerStyle;
        
        [self _updateKnobMode];
    }
}

- (BOOL)hovering
{
    NSPoint mouseLocation = [NSEvent mouseLocation];
    if ([NSWindow windowNumberAtPoint:mouseLocation belowWindowWithWindowNumber:0] != self.nsWindow.windowNumber) {
        return NO;
    }
    
    NSPoint windowLocation = [self.nsWindow convertRectFromScreen:(NSRect){mouseLocation, NSZeroSize}].origin;
    TUIView * hitTestView = [self.nsView.rootView hitTest:windowLocation withEvent:nil];
    return [hitTestView isDescendantOfView:self];
}

- (void)_updateKnobMode
{
    TUIScrollViewIndicatorVisibility visibility = TUIScrollViewIndicatorVisibleDefault;
    
    if ([self isVertical]) {
        visibility = scrollView.verticalScrollIndicatorVisibility;
    } else {
        visibility = scrollView.horizontalScrollIndicatorVisibility;
    }
    
    if (visibility == TUIScrollViewIndicatorVisibleNever) {
        return [self setKnobMode:TUIScrollKnobModeHidden animated:YES];
    }
    
    const BOOL hovering = self.hovering;
    
    if (_scrollKnobFlags.active) {
        if (hovering) {
            [self setKnobMode:TUIScrollKnobModeFullWidth animated:YES];
        } else if (_knobMode == TUIScrollKnobModeHidden) {
            [self setKnobMode:TUIScrollKnobModeCompact animated:YES];
        }
    } else if (!hovering) {
        if (_systemPreferedScrollerStyle == NSScrollerStyleOverlay) {
            [self setKnobMode:TUIScrollKnobModeHidden animated:YES];
        } else {
            [self setKnobMode:TUIScrollKnobModeCompact animated:YES];
        }
    }
}

- (TUIScrollKnobBackgroundView *)backgroundView
{
    if (!_backgroundView) {
        _backgroundView = [[TUIScrollKnobBackgroundView alloc] initWithFrame:self.bounds];
        [_backgroundView setLayout:^CGRect(TUIView * v) {
            return v.superview.bounds;
        }];
    }
    return _backgroundView;
}

+ (CGFloat)preferedSize
{
    return 16;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self.scrollerStyleNotificationObserver];
}

- (void)setKnobMode:(TUIScrollKnobMode)knobMode animated:(BOOL)animated
{
    if (_knobMode != knobMode) {
        _knobMode = knobMode;
        
        if (animated) {
            [TUIView animateWithDuration:0.2 animations:^{
                [self _updateWithKnobMode];
            }];
        } else {
            [self _updateWithKnobMode];
        }
    }
}

- (void)_updateWithKnobMode
{

    switch (_knobMode) {
        default:
        case TUIScrollKnobModeCompact:
            [self _updateKnobSizeTo:7.0];
            _backgroundView.alpha = 0.0;
            knob.alpha = 0.5;
            break;
        case TUIScrollKnobModeFullWidth:
            [self _updateKnobSizeTo:11.0];
            _backgroundView.alpha = 1.0;
            knob.alpha = 0.5;
            break;
        case TUIScrollKnobModeHidden:
            _backgroundView.alpha = 0.0;
            knob.alpha = 0.0;
            break;
    }
    [self _updateKnobPosition];
}

- (void)_updateKnobSizeTo:(CGFloat)size
{
    CGRect frame = knob.frame;
    if (self.isVertical) {
        frame.size.width = size;
    } else {
        frame.size.height = size;
    }
    knob.frame = frame;
    knob.layer.cornerRadius = size / 2;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (!self.nsWindow) {
        [self _deactivateKnob];
    }
}

- (void)_deactivateKnobWithDelay
{
    [self _cancelKnobDeactivation];
    [self performSelector:@selector(_deactivateKnob) withObject:nil afterDelay:TUIScrollIndicatorDisplayPeriod];
}

- (void)_cancelKnobDeactivation
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_deactivateKnob) object:nil];
}

- (void)setFrame:(CGRect)frame
{
    if (!CGRectEqualToRect(super.frame, frame)) {
        [self _activateKnob];
    }
    [super setFrame:frame];
}

- (void)_activateKnob
{
    [self _deactivateKnobWithDelay];

    if (_scrollKnobFlags.active) {
        return;
    }
    _scrollKnobFlags.active = 1;
    [self _updateKnobMode];
}

- (void)_deactivateKnob
{
    [self _cancelKnobDeactivation];
    
    if (!_scrollKnobFlags.active) {
        return;
    }
    
    const BOOL hovering = self.hovering;

    if (_scrollKnobFlags.trackingInsideKnob || hovering) {
        return;
    }
    _scrollKnobFlags.active = 0;
    [self _updateKnobMode];
}

- (BOOL)isVertical
{
    CGRect b = self.bounds;
    return b.size.height > b.size.width;
}

#define KNOB_CALCULATIONS(OFFSET, LENGTH, MIN_KNOB_SIZE) \
float proportion = visible.size.LENGTH / contentSize.LENGTH; \
float knobLength = trackBounds.size.LENGTH * proportion; \
if(knobLength < MIN_KNOB_SIZE) knobLength = MIN_KNOB_SIZE; \
float rangeOfMotion = trackBounds.size.LENGTH - knobLength; \
float maxOffset = contentSize.LENGTH - visible.size.LENGTH; \
float currentOffset = visible.origin.OFFSET; \
float offsetProportion = 1.0 - (maxOffset - currentOffset) / maxOffset; \
float knobOffset = offsetProportion * rangeOfMotion; \
if(isnan(knobOffset)) knobOffset = 0.0; \
if(isnan(knobLength)) knobLength = 0.0;

#define DEFAULT_MIN_KNOB_SIZE 33

- (void)_updateKnobPosition {
    CGRect trackBounds = self.bounds;
    CGRect visible = scrollView.visibleRect;
    CGSize contentSize = scrollView.contentSize;
    
    BOOL isVertical = self.isVertical;
    CGFloat knobSize = isVertical ? knob.bounds.size.width : knob.bounds.size.height;
    
    CGFloat knobMargin = 2;
    
    if(isVertical) {
        KNOB_CALCULATIONS(y, height, DEFAULT_MIN_KNOB_SIZE)
        
        CGRect frame;
        frame.origin.x = trackBounds.size.width - knobMargin - knobSize;
        frame.origin.y = knobOffset;
        frame.size.height = MIN(2000, knobLength);
        frame.size.width = knobSize;
        frame = ABRectRoundOrigin(CGRectInset(frame, 0, 4));
        knob.frame = frame;
    } else {
        KNOB_CALCULATIONS(x, width, DEFAULT_MIN_KNOB_SIZE)
        
        CGRect frame;
        frame.origin.x = knobOffset;
        frame.origin.y = knobMargin;
        frame.size.width = MIN(2000, knobLength);
        frame.size.height = knobSize;
        frame = ABRectRoundOrigin(CGRectInset(frame, 4, 0));
        knob.frame = frame;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self _updateKnobPosition];
}

- (void)flash {
    _scrollKnobFlags.flashing = 1;
    
    static const CFTimeInterval duration = 0.6f;
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    animation.duration = duration;
    animation.keyPath = @"opacity";
    animation.values = [NSArray arrayWithObjects:
                        [NSNumber numberWithDouble:0.5],
                        [NSNumber numberWithDouble:0.2],
                        [NSNumber numberWithDouble:0.0],
                        nil];
    [knob.layer addAnimation:animation forKey:@"opacity"];
    [self performSelector:@selector(_endFlashing) withObject:nil afterDelay:(duration - 0.01)];
}

- (void)_endFlashing
{
    _scrollKnobFlags.flashing = 0;
    
    [self.scrollView setNeedsLayout];
}

- (unsigned int)scrollIndicatorStyle {
    return _scrollKnobFlags.scrollIndicatorStyle;
}

- (void)setScrollIndicatorStyle:(unsigned int)style {
    _scrollKnobFlags.scrollIndicatorStyle = style;
    
    switch(style) {
        case TUIScrollViewIndicatorStyleLight:
            knob.backgroundColor = [TUIColor whiteColor];
            break;
        case TUIScrollViewIndicatorStyleDark:
        default:
            knob.backgroundColor = [TUIColor blackColor];
            break;
    }
}

- (void)mouseEntered:(NSEvent *)event
{
    [self _updateKnobMode];
    // make sure we propagate mouse events
    [super mouseEntered:event];
}

- (void)mouseExited:(NSEvent *)event
{
    [self _updateKnobMode];
    [self _deactivateKnobWithDelay];
    // make sure we propagate mouse events
    [super mouseExited:event];
}

- (void)mouseDown:(NSEvent *)event
{
    _mouseDown = [self localPointForEvent:event];
    _knobStartFrame = knob.frame;
    [self _activateKnob];

    if([knob pointInside:[self convertPoint:_mouseDown toView:knob] withEvent:event]) { // can't use hitTest because userInteractionEnabled is NO
        // normal drag-knob-scroll
        _scrollKnobFlags.trackingInsideKnob = 1;
    } else {
        // page-scroll
        _scrollKnobFlags.trackingInsideKnob = 0;
        
        CGRect visible = scrollView.visibleRect;
        CGPoint contentOffset = scrollView.contentOffset;
        
        if([self isVertical]) {
            if(_mouseDown.y < _knobStartFrame.origin.y) {
                contentOffset.y += visible.size.height;
            } else {
                contentOffset.y -= visible.size.height;
            }
        } else {
            if(_mouseDown.x < _knobStartFrame.origin.x) {
                contentOffset.x += visible.size.width;
            } else {
                contentOffset.x -= visible.size.width;
            }
        }
        
        [scrollView setContentOffset:contentOffset animated:YES];
    }
    
    [super mouseDown:event];
}

- (void)mouseUp:(NSEvent *)event
{
    _scrollKnobFlags.trackingInsideKnob = NO;
    [self _updateKnobMode];
    [self _deactivateKnobWithDelay];
    [super mouseUp:event];
}

#define KNOB_CALCULATIONS_REVERSE(OFFSET, LENGTH) \
CGRect knobFrame = _knobStartFrame; \
knobFrame.origin.OFFSET += diff.LENGTH; \
CGFloat knobOffset = knobFrame.origin.OFFSET; \
CGFloat minKnobOffset = 0.0; \
CGFloat maxKnobOffset = trackBounds.size.LENGTH - knobFrame.size.LENGTH; \
CGFloat proportion = (knobOffset - 1.0) / (maxKnobOffset - minKnobOffset); \
CGFloat maxContentOffset = contentSize.LENGTH - visible.size.LENGTH;

- (void)mouseDragged:(NSEvent *)event
{
    if(_scrollKnobFlags.trackingInsideKnob) { // normal knob drag
        CGPoint p = [self localPointForEvent:event];
        CGSize diff = CGSizeMake(p.x - _mouseDown.x, p.y - _mouseDown.y);
        
        CGRect trackBounds = self.bounds;
        CGRect visible = scrollView.visibleRect;
        CGSize contentSize = scrollView.contentSize;
        
        if([self isVertical]) {
            KNOB_CALCULATIONS_REVERSE(y, height)
            CGPoint scrollOffset = scrollView.contentOffset;
            scrollOffset.y = roundf(-proportion * maxContentOffset);
            scrollView.contentOffset = scrollOffset;
        } else {
            KNOB_CALCULATIONS_REVERSE(x, width)
            CGPoint scrollOffset = scrollView.contentOffset;
            scrollOffset.x = roundf(-proportion * maxContentOffset);
            scrollView.contentOffset = scrollOffset;
        }
    } else { // dragging in knob-track area
        // ignore
    }
}

- (BOOL)flashing
{
    return _scrollKnobFlags.flashing;
}

@end

@interface TUIScrollKnobBackgroundView ()

@property (nonatomic, strong) TUIView * border;

@end

@implementation TUIScrollKnobBackgroundView

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [TUIColor colorWithWhite:0.985 alpha:0.82];
        self.userInteractionEnabled = NO;
        
        [self addSubview:self.border];
    }
    return self;
}

- (BOOL)isVertical
{
    CGRect b = self.bounds;
    return b.size.height > b.size.width;
}

- (TUIView *)border
{
    if (!_border) {
        _border = [[TUIView alloc] initWithFrame:CGRectZero];
        _border.backgroundColor = [TUIColor colorWithWhite:0.0 alpha:0.08];
    }
    return _border;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.isVertical) {
        _border.frame = CGRectMake(0, 0, 1, self.bounds.size.height);
    } else {
        _border.frame = CGRectMake(0, self.bounds.size.height - 1, self.bounds.size.width, 1);
    }
}

@end

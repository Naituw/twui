//
//  TUITextRenderer_Private.h
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import "TUITextRenderer.h"

@interface TUITextRenderer ()
{
@protected
    __weak id<TUITextRendererEventDelegate> _eventDelegate;
    
    struct {
        unsigned int placeAttachment: 1;
    } _renderDelegateHas;
    
    struct {
        unsigned int contextView: 1;
        unsigned int activeRanges: 1;
        unsigned int didPressActiveRange: 1;
        unsigned int contextMenuForActiveRange: 1;
        unsigned int didPressAttachment: 1;
        unsigned int contextMenuForAttachment: 1;
        unsigned int shouldInteractWithActiveRange: 1;
        unsigned int willBecomeFirstResponder: 1;
        unsigned int didBecomeFirstResponder: 1;
        unsigned int willResignFirstResponder: 1;
        unsigned int didResignFirstResponder: 1;
        
        unsigned int mouseEnteredActiveRange: 1;
        unsigned int mouseMovedActiveRange: 1;
        unsigned int mouseExitedActiveRange: 1;
    } _eventDelegateHas;
    
    CGPoint _touchesBeginPoint;
}

@property (nonatomic, strong) id<ABActiveTextRange> pressingActiveRange;
@property (nonatomic, strong) id<ABActiveTextRange> savedPressingActiveRange;
@property (nonatomic, strong) id<ABActiveTextRange> hoveringActiveRange;
@property (atomic, copy) NSDictionary * activeRangeToRectsMap;

#pragma mark - Rendering Overrides

- (void)drawHighlightedBackgroundForActiveRange:(id<ABActiveTextRange>)activeRange rect:(CGRect)rect context:(CGContextRef)context;

@end

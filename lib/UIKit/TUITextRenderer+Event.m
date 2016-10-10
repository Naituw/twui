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

#import "TUITextRenderer+Event.h"
#import "TUITextRenderer_Private.h"
#import "TUITextRenderer+LayoutResult.h"
#import "CoreText+Additions.h"
#import "TUICGAdditions.h"
#import "TUIImage.h"
#import "TUINSView.h"
#import "TUINSWindow.h"
#import "TUIView+Private.h"
#import "TUIView.h"

@interface TUITextRenderer()
- (NSRange)_selectedRange;
@end

@implementation TUITextRenderer (Event)

+ (void)initialize
{
    static BOOL initialized = NO;
	if(!initialized) {
		initialized = YES;
		// set up Services
		[NSApp registerServicesMenuSendTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] returnTypes:@[]];
	}
}

- (id<TUITextRendererEventDelegate>)eventDelegate
{
    return _eventDelegate;
}

- (void)setEventDelegate:(id<TUITextRendererEventDelegate>)eventDelegate
{
    _eventDelegate = eventDelegate;
	
    _eventDelegateHas.contextView = [eventDelegate respondsToSelector:@selector(contextViewForTextRenderer:)];
    _eventDelegateHas.didPressActiveRange = [eventDelegate respondsToSelector:@selector(textRenderer:didClickActiveRange:)];
    _eventDelegateHas.activeRanges = [eventDelegate respondsToSelector:@selector(activeRangesForTextRenderer:)];
    _eventDelegateHas.contextMenuForActiveRange = [eventDelegate respondsToSelector:@selector(textRenderer:contextMenuForActiveRange:event:)];
    _eventDelegateHas.didPressAttachment = [eventDelegate respondsToSelector:@selector(textRenderer:didClickTextAttachment:)];
    _eventDelegateHas.contextMenuForAttachment = [eventDelegate respondsToSelector:@selector(textRenderer:contextMenuForTextAttachment:event:)];
    _eventDelegateHas.willBecomeFirstResponder = [eventDelegate respondsToSelector:@selector(textRendererWillBecomeFirstResponder:)];
    _eventDelegateHas.didBecomeFirstResponder = [eventDelegate respondsToSelector:@selector(textRendererDidBecomeFirstResponder:)];
    _eventDelegateHas.willResignFirstResponder = [eventDelegate respondsToSelector:@selector(textRendererWillResignFirstResponder:)];
    _eventDelegateHas.didResignFirstResponder = [eventDelegate respondsToSelector:@selector(textRendererDidResignFirstResponder:)];
    
    _eventDelegateHas.mouseEnteredActiveRange = [eventDelegate respondsToSelector:@selector(textRenderer:mouseEnteredActiveRange:)];
    _eventDelegateHas.mouseMovedActiveRange = [eventDelegate respondsToSelector:@selector(textRenderer:mouseMovedInActiveRange:)];
    _eventDelegateHas.mouseExitedActiveRange = [eventDelegate respondsToSelector:@selector(textRenderer:mouseExitedFromActiveRange:)];
}

- (CGPoint)localPointForEvent:(NSEvent *)event
{
	return [self.eventDelegateContextView localPointForEvent:event];
}

- (CFIndex)stringIndexForEvent:(NSEvent *)event
{
	return [self characterIndexForPoint:[self localPointForEvent:event]];
}

- (id<ABActiveTextRange>)rangeInRanges:(NSArray *)ranges forStringIndex:(CFIndex)index
{
	for(id<ABActiveTextRange> rangeValue in ranges) {
		NSRange range = [rangeValue rangeValue];
		if(NSLocationInRange(index, range))
			return rangeValue;
	}
	return nil;
}

- (id<ABActiveTextRange>)fast_rangeAtLocalPoint:(CGPoint)location
{
    location = [self convertPointToLayout:location];
    NSDictionary * map = self.activeRangeToRectsMap;
    for (id<ABActiveTextRange>key in map) {
        NSArray * rects = map[key];
        for (NSValue * value in rects) {
            CGRect rect = [value rectValue];
            if (CGRectContainsPoint(rect, location)) {
                return key;
            }
        }
    }
    return nil;
}

- (id<ABActiveTextRange>)fast_rangeForEvent:(NSEvent *)event
{
    CGPoint localPoint = [self localPointForEvent:event];
    return [self fast_rangeAtLocalPoint:localPoint];
}

- (TUIImage *)dragImageForSelection:(NSRange)selection
{
	CGRect b = self.eventDelegateContextView.frame;
	
	_flags.drawMaskDragSelection = 1;
	TUIImage *image = TUIGraphicsDrawAsImage(b.size, ^{
		[self draw];
	});
	_flags.drawMaskDragSelection = 0;
	return image;
}

- (BOOL)beginWaitForDragInRange:(NSRange)range string:(NSString *)string
{
	CFAbsoluteTime downTime = CFAbsoluteTimeGetCurrent();
	NSEvent *nextEvent = [NSApp nextEventMatchingMask:NSAnyEventMask
											untilDate:[NSDate distantFuture]
											   inMode:NSEventTrackingRunLoopMode
											  dequeue:YES];
	CFAbsoluteTime nextEventTime = CFAbsoluteTimeGetCurrent();
	if(([nextEvent type] == NSLeftMouseDragged) && (nextEventTime > downTime + 0.11)) {
		NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
		[pasteboard clearContents];
		[pasteboard writeObjects:[NSArray arrayWithObject:string]];
		NSRect f = [self.eventDelegateContextView frameInNSView];
		
		CFIndex saveStart = _selectionStart;
		CFIndex saveEnd = _selectionEnd;
		_selectionStart = range.location;
		_selectionEnd = range.location + range.length;
		TUIImage *dragImage = [self dragImageForSelection:range];
		_selectionStart = saveStart;
		_selectionEnd = saveEnd;
		
		NSImage *image = [[NSImage alloc] initWithCGImage:dragImage.CGImage size:NSZeroSize];
		
		[self.eventDelegateContextView.nsView dragImage:image
							at:f.origin
						offset:NSZeroSize
						 event:nextEvent 
					pasteboard:pasteboard 
						source:self 
					 slideBack:YES];
		return YES;
	} else {
		return NO;
	}
}

- (void)mouseDown:(NSEvent *)event
{
	CGRect previousSelectionRect = [self rectForCurrentSelection];
	
	switch([event clickCount]) {
		case 4:
			_selectionAffinity = TUITextSelectionAffinityParagraph;
			break;
		case 3:
			_selectionAffinity = TUITextSelectionAffinityLine;
			break;
		case 2:
			_selectionAffinity = TUITextSelectionAffinityWord;
			break;
		default:
			_selectionAffinity = TUITextSelectionAffinityCharacter;
			break;
	}
    
	CFIndex eventIndex = [self stringIndexForEvent:event];
    CGPoint eventLocation = [self.eventDelegateContextView localPointForEvent:event];
    TUITextAttachment * __block hitTextAttachment = nil;
    id<ABActiveTextRange> hitActiveRange = nil;
    
    [self.attributedString tui_enumerateTextAttachments:^(TUITextAttachment *attachment, NSRange range, BOOL *stop) {
        if (attachment.userInteractionEnabled && CGRectContainsPoint(attachment.derivedFrame, eventLocation)) {
            hitTextAttachment = attachment;
            *stop = YES;
        }
    }];
    
    if (hitTextAttachment) {
        if (hitTextAttachment.userInteractionEnabled) {
            _selectionAffinity = TUITextSelectionAffinityCharacter; // don't select text when we are clicking interactable attachment
        }
        goto normal;
    }
    
    {
        NSArray * ranges = [self eventDelegateActiveRanges];
        if (ranges) {
            hitActiveRange = [self rangeInRanges:ranges forStringIndex:eventIndex];
        }
    }

	if([event clickCount] > 1)
		goto normal; // we want double-click-drag-select-by-word, not drag selected text
	
	if(hitActiveRange) {
		self.hitRange = hitActiveRange;
		[self.eventDelegateContextView redraw];
		self.hitRange = nil;
		
		NSRange r = [hitActiveRange rangeValue];
		NSString *s = [[self.attributedString string] substringWithRange:r];
				
		if(![self beginWaitForDragInRange:r string:s])
			goto normal;
	} else if(NSLocationInRange(eventIndex, [self selectedRange])) {
		if(![self beginWaitForDragInRange:[self selectedRange] string:[self selectedString]])
			goto normal;
	} else {
normal:
		if(([event modifierFlags] & NSShiftKeyMask) != 0) {
			CFIndex newIndex = [self stringIndexForEvent:event];
			if(newIndex < _selectionStart) {
				_selectionStart = newIndex;
			} else {
				_selectionEnd = newIndex;
			}
		} else {
			_selectionStart = [self stringIndexForEvent:event];
			_selectionEnd = _selectionStart;
		}
		
		self.hitRange = hitActiveRange;
        self.hitAttachment = hitTextAttachment;
	}
	
	CGRect totalRect = CGRectUnion(previousSelectionRect, [self rectForCurrentSelection]);
	[self.eventDelegateContextView setNeedsDisplayInRect:totalRect];
	if([self acceptsFirstResponder])
		[[self.eventDelegateContextView nsWindow] tui_makeFirstResponder:self];
}

- (void)mouseUp:(NSEvent *)event
{
    CGRect previousSelectionRect = [self rectForCurrentSelection];

    if (_flags.isFirstResponder) {
        
        if(([event modifierFlags] & NSShiftKeyMask) == 0) {
            CFIndex i = [self stringIndexForEvent:event];
            _selectionEnd = i;
        }
        
        // fixup selection based on selection affinity
        BOOL flip = _selectionEnd < _selectionStart;
        NSRange trueRange = [self _selectedRange];
        _selectionStart = trueRange.location;
        _selectionEnd = _selectionStart + trueRange.length;
        if(flip) {
            // maintain anchor point, if we select with mouse, then start using keyboard to tweak
            CFIndex x = _selectionStart;
            _selectionStart = _selectionEnd;
            _selectionEnd = x;
        }
        
        _selectionAffinity = TUITextSelectionAffinityCharacter; // reset affinity
    }
	
	CGRect totalRect = CGRectUnion(previousSelectionRect, [self rectForCurrentSelection]);
	[self.eventDelegateContextView setNeedsDisplayInRect:totalRect];
    
    if (self.hitRange) {
        [self eventDelegateDidClickActiveRange:self.hitRange];
    }
    self.hitRange = nil;
    
    if (self.hitAttachment) {
        [self eventDelegateDidClickAttachment:self.hitAttachment];
    }
    self.hitAttachment = nil;
}

- (void)mouseDragged:(NSEvent *)event
{
	CGRect previousSelectionRect = [self rectForCurrentSelection];
	
    if (_flags.isFirstResponder) {
        CFIndex i = [self stringIndexForEvent:event];
        _selectionEnd = i;
    }
	
	CGRect totalRect = CGRectUnion(previousSelectionRect, [self rectForCurrentSelection]);
	[self.eventDelegateContextView setNeedsDisplayInRect:totalRect];
    
    self.hitRange = nil;
    self.hitAttachment = nil;
}

- (void)_updateHoveringActiveRangeWithEvent:(NSEvent *)event
{
    id<ABActiveTextRange>range = [self fast_rangeForEvent:event];
    
    id<ABActiveTextRange>currentRange = self.hoveringActiveRange;
    if (range == currentRange) {
        if (range && _eventDelegateHas.mouseMovedActiveRange) {
            [_eventDelegate textRenderer:self mouseMovedInActiveRange:range];
        }
        return;
    }
 
    self.hoveringActiveRange = range;
    
    if (currentRange) {
        if (_eventDelegateHas.mouseExitedActiveRange) {
            [_eventDelegate textRenderer:self mouseExitedFromActiveRange:currentRange];
        }
    }
    if (range) {
        if (_eventDelegateHas.mouseEnteredActiveRange) {
            [_eventDelegate textRenderer:self mouseEnteredActiveRange:range];
        }
    }
}

- (void)mouseEntered:(NSEvent *)event
{
    if (!_eventDelegateHas.mouseEnteredActiveRange) {
        return;
    }
    [self _updateHoveringActiveRangeWithEvent:event];
}

- (void)mouseExited:(NSEvent *)event
{
    if (!_eventDelegateHas.mouseEnteredActiveRange) {
        return;
    }
    [self _updateHoveringActiveRangeWithEvent:event];
}

- (void)mouseMoved:(NSEvent *)event
{
    if (!_eventDelegateHas.mouseEnteredActiveRange) {
        return;
    }
    [self _updateHoveringActiveRangeWithEvent:event];
}

- (void)invalidateHover
{
    id<ABActiveTextRange> range = self.hoveringActiveRange;
    if (range) {
        self.hoveringActiveRange = nil;
        if (_eventDelegateHas.mouseExitedActiveRange) {
            [_eventDelegate textRenderer:self mouseExitedFromActiveRange:range];
        }
    }
}

- (id<ABActiveTextRange>)activeRangeForLocation:(CGPoint)point
{
    CFIndex index = [self characterIndexForPoint:point];
    NSArray * ranges = [self eventDelegateActiveRanges];

    if (ranges) {
        id<ABActiveTextRange> range = [self rangeInRanges:ranges forStringIndex:index];
        return range;
    }
    
    return nil;
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    if (_eventDelegateHas.contextMenuForActiveRange) {
        CFIndex eventIndex = [self stringIndexForEvent:event];
        NSArray * ranges = [self eventDelegateActiveRanges];
        if (ranges) {
            id<ABActiveTextRange> range = [self rangeInRanges:ranges forStringIndex:eventIndex];
            if (range) {
                NSMenu * menu = [_eventDelegate textRenderer:self contextMenuForActiveRange:range event:event];
                if (menu) {
                    return menu;
                }
            }
        }
    }
    
    if (_eventDelegateHas.contextMenuForAttachment) {
        CGPoint eventLocation = [self.eventDelegateContextView localPointForEvent:event];
        TUITextAttachment * __block hitTextAttachment = nil;
        
        [self.attributedString tui_enumerateTextAttachments:^(TUITextAttachment *attachment, NSRange range, BOOL *stop) {
            if (attachment.userInteractionEnabled && CGRectContainsPoint(attachment.derivedFrame, eventLocation)) {
                hitTextAttachment = attachment;
                *stop = YES;
            }
        }];
        
        if (hitTextAttachment) {
            NSMenu * menu = [_eventDelegate textRenderer:self contextMenuForTextAttachment:hitTextAttachment event:event];
            if (menu) {
                return menu;
            }
        }
    }
    
    return [super menuForEvent:event];
}

- (CGRect)rectForCurrentSelection {
    return [self boundingRectForCharacterRange:[self _selectedRange]];
}

- (void)resetSelection
{
    if (_selectionStart || _selectionEnd || _selectionAffinity != TUITextSelectionAffinityCharacter || self.hitRange) {
        _selectionStart = 0;
        _selectionEnd = 0;
        _selectionAffinity = TUITextSelectionAffinityCharacter;
        self.hitRange = nil;
        [self.eventDelegateContextView setNeedsDisplay];
    }
}

- (void)selectAll:(id)sender
{
	_selectionStart = 0;
	_selectionEnd = [[self.attributedString string] length];
	_selectionAffinity = TUITextSelectionAffinityCharacter;
	[self.eventDelegateContextView setNeedsDisplay];
}

- (void)copy:(id)sender
{
	NSString *selectedString = [self selectedString];
	if ([selectedString length] > 0) {
		[[NSPasteboard generalPasteboard] clearContents];
		[[NSPasteboard generalPasteboard] writeObjects:[NSArray arrayWithObject:selectedString]];
	} else {
		[[self nextResponder] tryToPerform:@selector(copy:) with:sender];
	}
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	// TODO: obviously these shouldn't be called at exactly the same time...
	if(_eventDelegateHas.willBecomeFirstResponder) [_eventDelegate textRendererWillBecomeFirstResponder:self];
	if(_eventDelegateHas.didBecomeFirstResponder) [_eventDelegate textRendererDidBecomeFirstResponder:self];
    _flags.isFirstResponder = YES;
    
	return YES;
}

- (BOOL)resignFirstResponder
{
    _flags.isFirstResponder = NO;
	// TODO: obviously these shouldn't be called at exactly the same time...
	if(_eventDelegateHas.willResignFirstResponder) [_eventDelegate textRendererWillResignFirstResponder:self];
	[self resetSelection];
	if(_eventDelegateHas.didResignFirstResponder) [_eventDelegate textRendererDidResignFirstResponder:self];
    
	return YES;
}

// Services

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
{
	if([sendType isEqualToString:NSStringPboardType] && !returnType) {
		if([[self selectedString] length] > 0)
			return self;
	}
	return [super validRequestorForSendType:sendType returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
    if(![types containsObject:NSStringPboardType])
        return NO;
	
	[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    return [pboard setString:[self selectedString] forType:NSStringPboardType];
}

- (void)quickLookWithEvent:(NSEvent *)event
{
    NSInteger idx = [self stringIndexForEvent:event];
    NSAttributedString * string = [self attributedString];
    
    idx = MIN(string.length - 1, idx);
    
    NSRange range = [string doubleClickAtIndex:idx];
    
    NSAttributedString * target = [string attributedSubstringFromRange:range];
    
    if (!target.length) return;
    
    NSRect rect = [self firstSelectionRectForCharacterRange:range];
    NSPoint point = rect.origin;
    
    NSUInteger characterIndex = [self characterIndexForPoint:[self localPointForEvent:event]];
    
    if (characterIndex == NSNotFound) {
        return;
    }
    
    NSUInteger lineFragmentIndex = [self lineFragmentIndexForCharacterAtIndex:characterIndex];
    if (lineFragmentIndex == NSNotFound) {
        return;
    }
    
    TUIFontMetrics lineMetrics = [self.textLayout lineFragmentMetricsForLineAtIndex:lineFragmentIndex effectiveRange:NULL];
    
    point.y += lineMetrics.descent;
    //point.y += leading;
    
    point = [self.eventDelegateContextView convertPoint:point toView:self.eventDelegateContextView.nsView.rootView];
    
    [self.eventDelegateContextView.nsView showDefinitionForAttributedString:target atPoint:point];
}

- (TUIView *)eventDelegateContextView
{
    if (_eventDelegateHas.contextView) {
        return [_eventDelegate contextViewForTextRenderer:self];
    }
    return nil;
}

- (NSArray *)eventDelegateActiveRanges
{
    if (_eventDelegateHas.activeRanges) {
        return [_eventDelegate activeRangesForTextRenderer:self];
    }
    return nil;
}

- (NSArray *)activeRanges
{
    return [self eventDelegateActiveRanges];
}

- (void)eventDelegateDidClickActiveRange:(id<ABActiveTextRange>)activeRange
{
    if (self.disablesActionSending || self.eventDelegateContextView.disablesActionSending) {
        return;
    }
    if (_eventDelegateHas.didPressActiveRange) {
        [_eventDelegate textRenderer:self didClickActiveRange:activeRange];
    }
}

- (void)eventDelegateDidClickAttachment:(TUITextAttachment *)attachment
{
    if (self.disablesActionSending || self.eventDelegateContextView.disablesActionSending) {
        return;
    }
    if (_eventDelegateHas.didPressAttachment) {
        [_eventDelegate textRenderer:self didClickTextAttachment:attachment];
    }
}

@end

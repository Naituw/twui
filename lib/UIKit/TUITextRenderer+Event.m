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
#import "CoreText+Additions.h"
#import "TUICGAdditions.h"
#import "TUIImage.h"
#import "TUINSView.h"
#import "TUINSWindow.h"
#import "TUIView+Private.h"
#import "TUIView.h"

@interface TUITextRenderer()
- (CTFramesetterRef)ctFramesetter;
- (CTFrameRef)ctFrame;
- (CGPathRef)ctPath;
- (CFRange)_selectedRange;
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
    _eventDelegateHas.didPressAttachment = [eventDelegate respondsToSelector:@selector(textRenderer:didClickTextAttachment:)];
    _eventDelegateHas.contextMenuForAttachment = [eventDelegate respondsToSelector:@selector(textRenderer:contextMenuForTextAttachment:event:)];
    _eventDelegateHas.willBecomeFirstResponder = [eventDelegate respondsToSelector:@selector(textRendererWillBecomeFirstResponder:)];
    _eventDelegateHas.didBecomeFirstResponder = [eventDelegate respondsToSelector:@selector(textRendererDidBecomeFirstResponder:)];
    _eventDelegateHas.willResignFirstResponder = [eventDelegate respondsToSelector:@selector(textRendererWillResignFirstResponder:)];
    _eventDelegateHas.didResignFirstResponder = [eventDelegate respondsToSelector:@selector(textRendererDidResignFirstResponder:)];
}

- (CGPoint)localPointForEvent:(NSEvent *)event
{
	CGPoint p = [self.eventDelegateContextView localPointForEvent:event];
	p.x -= frame.origin.x;
	p.y -= frame.origin.y;
	return p;
}

- (CFIndex)stringIndexForPoint:(CGPoint)p
{
	return AB_CTFrameGetStringIndexForPosition([self ctFrame], p);
}

- (CFIndex)stringIndexForEvent:(NSEvent *)event
{
	return [self stringIndexForPoint:[self localPointForEvent:event]];
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
		NSString *s = [[attributedString string] substringWithRange:r];
		
		// bit of a hack
		if(hitActiveRange.rangeFlavor == ABActiveTextRangeFlavorURL) {
			if([hitActiveRange respondsToSelector:@selector(url)]) {
				NSString *urlString = [[hitActiveRange performSelector:@selector(url)] absoluteString];
				if(urlString)
					s = urlString;
			}
		}
		
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
	
	if(([event modifierFlags] & NSShiftKeyMask) == 0) {
		CFIndex i = [self stringIndexForEvent:event];
		_selectionEnd = i;
	}
	
	// fixup selection based on selection affinity
	BOOL flip = _selectionEnd < _selectionStart;
	CFRange trueRange = [self _selectedRange];
	_selectionStart = trueRange.location;
	_selectionEnd = _selectionStart + trueRange.length;
	if(flip) {
		// maintain anchor point, if we select with mouse, then start using keyboard to tweak
		CFIndex x = _selectionStart;
		_selectionStart = _selectionEnd;
		_selectionEnd = x;
	}
	
	_selectionAffinity = TUITextSelectionAffinityCharacter; // reset affinity
	
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
	
	CFIndex i = [self stringIndexForEvent:event];
	_selectionEnd = i;
	
	CGRect totalRect = CGRectUnion(previousSelectionRect, [self rectForCurrentSelection]);
	[self.eventDelegateContextView setNeedsDisplayInRect:totalRect];
    
    self.hitRange = nil;
    self.hitAttachment = nil;
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
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
	return [self rectForRange:[self _selectedRange]];
}

- (CGRect)rectForRange:(CFRange)range {
	CTFrameRef textFrame = [self ctFrame];
	CGRect totalRect = CGRectNull;
	if(range.length > 0) {
		CFIndex rectCount = 100;
		CGRect rects[rectCount];
		AB_CTFrameGetRectsForRangeWithAggregationType(textFrame, range, AB_CTLineRectAggregationTypeBlock, rects, &rectCount);
		
		for(CFIndex i = 0; i < rectCount; ++i) {
			CGRect rect = rects[i];
			rect = CGRectIntegral(rect);
			
			if(CGRectEqualToRect(totalRect, CGRectNull)) {
				totalRect = rect;
			} else {
				totalRect = CGRectUnion(rect, totalRect);
			}
		}
	}
	
	return totalRect;
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
	_selectionEnd = [[attributedString string] length];
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
	
	return YES;
}

- (BOOL)resignFirstResponder
{
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
    
    NSRange range = [string doubleClickAtIndex:idx];
    
    NSAttributedString * target = [string attributedSubstringFromRange:range];
    
    if (!target.length) return;
    
    NSRect rect = [self firstRectForCharacterRange:ABCFRangeFromNSRange(range)];
    NSPoint point = rect.origin;
    
    CGFloat descent, leading;
    
    AB_CTFrameGetTypographicBoundsForLineAtPosition(self.ctFrame, [self localPointForEvent:event], NULL, &descent, &leading);
    
    point.y += descent;
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

- (void)eventDelegateDidClickActiveRange:(id<ABActiveTextRange>)activeRange
{
    if (_eventDelegateHas.didPressActiveRange) {
        [_eventDelegate textRenderer:self didClickActiveRange:activeRange];
    }
}

- (void)eventDelegateDidClickAttachment:(TUITextAttachment *)attachment
{
    if (_eventDelegateHas.didPressAttachment) {
        [_eventDelegate textRenderer:self didClickTextAttachment:attachment];
    }
}

@end

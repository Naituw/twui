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

#import "TUIKit.h"
#import "TUIView+PasteboardDragging.h"

@implementation TUIView (PasteboardDragging)

- (BOOL)pasteboardDraggingEnabled
{
	return _viewFlags.pasteboardDraggingEnabled;
}

- (void)setPasteboardDraggingEnabled:(BOOL)e
{
	_viewFlags.pasteboardDraggingEnabled = e;
}

- (void)startPasteboardDragging
{
	// implemented by subclasses
}

- (void)endPasteboardDragging:(NSDragOperation)operation
{
	// implemented by subclasses
}

- (id<NSPasteboardWriting>)representedPasteboardObject
{
	return nil;
}

- (TUIView *)handleForPasteboardDragView
{
	return self;
}

- (void)pasteboardDragMouseDown:(NSEvent *)event
{
	_viewFlags.pasteboardDraggingIsDragging = NO;
}

- (void)pasteboardDragMouseDragged:(NSEvent *)event
{
	if(!_viewFlags.pasteboardDraggingIsDragging) {
		_viewFlags.pasteboardDraggingIsDragging = YES;
		
		TUIView *dragView = [self handleForPasteboardDragView];
		id<NSPasteboardWriting> pasteboardObject = [dragView representedPasteboardObject];
		
		TUIImage *dragImage = TUIGraphicsDrawAsImage(dragView.frame.size, ^{
			[TUIGraphicsGetImageForView(dragView) drawAtPoint:CGPointZero blendMode:kCGBlendModeNormal alpha:0.75];
		});
		
		NSImage *dragNSImage = [[NSImage alloc] initWithCGImage:dragImage.CGImage size:NSZeroSize];
        NSDraggingItem * item = [[NSDraggingItem alloc] initWithPasteboardWriter:pasteboardObject];
        [item setDraggingFrame:[dragView frameInNSView] contents:dragNSImage];
        
        [self.nsView beginDraggingSessionWithItems:@[item] event:event source:self];
	}
}

- (void)draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint
{
    [[self handleForPasteboardDragView] startPasteboardDragging];
}

- (void)draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint
{
    
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
    [self.nsView mouseUp:nil]; // will clear _trackingView
    [[self handleForPasteboardDragView] endPasteboardDragging:operation];
}

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    return NSDragOperationCopy;
}

@end

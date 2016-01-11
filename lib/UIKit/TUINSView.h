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

#import <Cocoa/Cocoa.h>
#import "TUIHostView.h"
#import "TUIView+TUIBridgedView.h"

@class TUITextRenderer;

@protocol TUINSViewDelegate;
/**
 TUINSView is the bridge that hosts a TUIView-based interface heirarchy. You may add it as the contentView of your window if you want to build a pure TwUI-based UI, or you can use it for a small part.
 */
@interface TUINSView : NSView <TUIHostView>
{
	TUIView *_hoverView;

	__weak TUIView *_trackingView; // dragging view, weak
	__weak TUIView *_hyperFocusView; // weak

	TUIView *_hyperFadeView;
	void(^_hyperCompletion)(BOOL);
	
	NSTrackingArea *_trackingArea;
	
	__weak TUITextRenderer *_tempTextRendererForTextInputClient; // weak, set temporarily while NSTextInputClient dicks around
	
	BOOL deliveringEvent;
	BOOL inLiveResize;
	
	BOOL opaque;
}

/**
 Set this as the root TUIView-based view.
 */
@property (nonatomic, strong) TUIView *rootView;
@property (nonatomic, assign) id<TUINSViewDelegate> viewDelegate;

- (TUIView *)viewForLocationInWindow:(NSPoint)locationInWindow;
- (TUIView *)viewForEvent:(NSEvent *)event; // ignores views with 'userInteractionEnabled=NO'

- (void)setEverythingNeedsDisplay;
- (void)invalidateHoverForView:(TUIView *)v;

- (NSMenu *)menuWithPatchedItems:(NSMenu *)menu; // don't use this

- (BOOL)isTrackingSubviewOfView:(TUIView *)v;
- (BOOL)isHoveringSubviewOfView:(TUIView *)v; // v or subview of v
- (BOOL)isHoveringView:(TUIView *)v; // only v

- (TUIView *)hoverView;
- (void)ab_setIsOpaque:(BOOL)o __attribute__((deprecated)); // don't use this

- (void)tui_setOpaque:(BOOL)o;

- (BOOL)isWindowKey;

@end

#import <QuartzCore/QuartzCore.h>
@class TUIViewController;

@protocol TUINSViewDelegate <NSObject>

@optional
- (void)nsView:(TUINSView *)nsView mouseEntered:(NSEvent *)event;
- (void)nsView:(TUINSView *)nsView mouseExited:(NSEvent *)event;
- (void)nsView:(TUINSView *)nsView mouseMoved:(NSEvent *)event;
- (void)nsView:(TUINSView *)nsView mouseUp:(NSEvent *)event;
- (void)nsView:(TUINSView *)nsView rightMouseDown:(NSEvent *)event;
- (void)nsView:(TUINSView *)nsView rightMouseUp:(NSEvent *)event;
- (NSMenu *)nsView:(TUINSView *)nsView menuForEvent:(NSEvent *)event;
- (void)nsView:(TUINSView *)nsView scrollWheel:(NSEvent *)event;

- (void)nsView:(TUINSView *)nsView previewViewController:(TUIViewController *)controller sourceRect:(CGRect)sourceRect contentSize:(CGSize)contentSize;

@end

#import "TUINSView+Hyperfocus.h"

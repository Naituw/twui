//
//  TUIVisualEffectView.m
//  TwUI
//
//  Created by 吴天 on 16/2/12.
//
//

#import "TUIVisualEffectView.h"

@interface TUIVisualEffectView ()

@property (nonatomic, strong) NSVisualEffectView * backingView;
@property (nonatomic, strong) TUIView * blurTintView;

@end

@implementation TUIVisualEffectView

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [TUIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        
        // TODO: fallback for old systems
        
        NSVisualEffectView * effectView = [[NSVisualEffectView alloc] initWithFrame:frame];
        effectView.material = NSVisualEffectMaterialLight;
        effectView.state = NSVisualEffectStateActive;
        effectView.wantsLayer = YES;
        
        self.backingView = effectView;
        
        [self.layer addSublayer:effectView.layer];
        [self addSubview:self.blurTintView];
        
        [self updateEffectViewState];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _backingView.frame = CGRectInset(self.bounds, -6, 0);
    _blurTintView.frame = self.bounds;
}

- (TUIView *)blurTintView
{
    if (!_blurTintView) {
        _blurTintView = [[TUIView alloc] initWithFrame:CGRectZero];
        _blurTintView.userInteractionEnabled = NO;
    }
    return _blurTintView;
}

- (void)setTintColor:(TUIColor *)tintColor
{
    _blurTintView.backgroundColor = tintColor;
}

- (TUIColor *)tintColor
{
    return _blurTintView.backgroundColor;
}

- (void)setTintBlendingMode:(TUIViewBlendingMode)tintBlendingMode
{
    _blurTintView.blendingMode = tintBlendingMode;
}

- (TUIViewBlendingMode)tintBlendingMode
{
    return _blurTintView.blendingMode;
}

- (void)setMaterialBlendingMode:(TUIVisualEffectBlendingMode)materialBlendingMode
{
    _backingView.blendingMode = (NSVisualEffectBlendingMode)materialBlendingMode;
}

- (TUIVisualEffectBlendingMode)materialBlendingMode
{
    return (TUIVisualEffectBlendingMode)_backingView.blendingMode;
}

- (void)setMaterial:(TUIVisualEffectMaterial)material
{
    if (_material != material) {
        _material = material;
        
        if (material == TUIVisualEffectMaterialLight) {
            _backingView.material = NSVisualEffectMaterialLight;
        } else if (material == TUIVisualEffectMaterialDark) {
            _backingView.material = NSVisualEffectMaterialDark;
        } else if (material == TUIVisualEffectMaterialTitleBar) {
            _backingView.material = NSVisualEffectMaterialTitlebar;
        } else if (material == TUIVisualEffectMaterialUltraDark) {
            if (AtLeastElCapitan) {
                _backingView.material = NSVisualEffectMaterialUltraDark;
            } else {
                _backingView.material = NSVisualEffectMaterialDark;
            }
        }
    }
}

- (void)setState:(TUIVisualEffectState)state
{
    if (_state != state) {
        _state = state;
        
        [self updateEffectViewState];
    }
}

- (void)updateEffectViewState
{
    NSVisualEffectState targetState = NSVisualEffectStateActive;
    switch (_state) {
        case TUIVisualEffectStateInactive: {
            targetState = NSVisualEffectStateInactive;
        }
            break;
        case TUIVisualEffectStateFollowsWindowActiveState: {
            if (!self.nsWindow.isKeyWindow) {
                targetState = NSVisualEffectStateInactive;
            }
        }
            break;
        default:
            break;
    }
    
    if (_backingView.state != targetState) {
        _backingView.state = targetState;
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self updateEffectViewState];
}

- (void)windowDidBecomeKey
{
    [super windowDidBecomeKey];
    [self updateEffectViewState];
}

- (void)windowDidResignKey
{
    [self updateEffectViewState];
}

@end
